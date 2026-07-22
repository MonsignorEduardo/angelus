/* IAU 2006/2000A transformation to tropical ecliptic coordinates of date. */

#include "frames.h"

#include "erfa.h"
#include "erfam.h"

#include <cspice/SpiceUsr.h>

#include <math.h>
#include <stdio.h>

static void matrix_vector(const double matrix[3][3], const double input[3],
                          double output[3]) {
  for (int row = 0; row < 3; row++)
    output[row] = matrix[row][0] * input[0] + matrix[row][1] * input[1] +
                  matrix[row][2] * input[2];
}

static void matrix_derivative(const double after[3][3], const double before[3][3],
                              double step_seconds, double derivative[3][3]) {
  for (int row = 0; row < 3; row++)
    for (int column = 0; column < 3; column++)
      derivative[row][column] =
          (after[row][column] - before[row][column]) / (2.0 * step_seconds);
}

static void add_vectors(const double left[3], const double right[3], double result[3]) {
  for (int index = 0; index < 3; index++)
    result[index] = left[index] + right[index];
}

static int angular_coordinates(const double position[3], const double velocity[3],
                               double *longitude, double *latitude,
                               double *longitude_rate_day, double *latitude_rate_day,
                               char *error, int error_size) {
  double xy_squared = position[0] * position[0] + position[1] * position[1];
  double radius_squared = xy_squared + position[2] * position[2];
  if (xy_squared <= 1.0e-30 || radius_squared <= 1.0e-30) {
    snprintf(error, (size_t)error_size, "%s", "degenerate direction vector");
    return 0;
  }

  double xy = sqrt(xy_squared);
  double xy_rate = (position[0] * velocity[0] + position[1] * velocity[1]) / xy;
  *longitude = eraAnp(atan2(position[1], position[0]));
  *latitude = atan2(position[2], xy);
  *longitude_rate_day =
      (position[0] * velocity[1] - position[1] * velocity[0]) / xy_squared * ERFA_DAYSEC;
  *latitude_rate_day =
      (xy * velocity[2] - position[2] * xy_rate) / radius_squared * ERFA_DAYSEC;
  return 1;
}

static void get_cspice_error(char *error, int error_size) {
  SpiceChar message[1024] = {0};
  getmsg_c("LONG", sizeof(message), message);
  reset_c();
  snprintf(error, (size_t)error_size, "%s", message);
}

int astro_true_ecliptic_coordinates(double et,
                                     const double position_eclipj2000[3],
                                     double *longitude_rad,
                                     double *latitude_rad,
                                     double *declination_rad, char *error,
                                     int error_size) {
  SpiceDouble eclipj2000_to_j2000[3][3];
  pxform_c("ECLIPJ2000", "J2000", et, eclipj2000_to_j2000);
  if (failed_c()) {
    get_cspice_error(error, error_size);
    return 0;
  }

  double j2000[3];
  matrix_vector(eclipj2000_to_j2000, position_eclipj2000, j2000);

  double tt = unitim_c(et, "ET", "TDT");
  if (failed_c()) {
    get_cspice_error(error, error_size);
    return 0;
  }

  double date1 = ERFA_DJ00;
  double date2 = tt / ERFA_DAYSEC;
  double bias_precession_nutation[3][3];
  eraPnm06a(date1, date2, bias_precession_nutation);

  double true_equatorial[3];
  matrix_vector(bias_precession_nutation, j2000, true_equatorial);

  double dpsi;
  double deps;
  eraNut06a(date1, date2, &dpsi, &deps);
  double true_obliquity = eraObl06(date1, date2) + deps;
  double cosine = cos(true_obliquity);
  double sine = sin(true_obliquity);
  double true_ecliptic[3] = {
      true_equatorial[0],
      cosine * true_equatorial[1] + sine * true_equatorial[2],
      -sine * true_equatorial[1] + cosine * true_equatorial[2]};

  *longitude_rad = eraAnp(atan2(true_ecliptic[1], true_ecliptic[0]));
  *latitude_rad = atan2(true_ecliptic[2],
                        hypot(true_ecliptic[0], true_ecliptic[1]));
  *declination_rad = atan2(true_equatorial[2],
                           hypot(true_equatorial[0], true_equatorial[1]));
  return 1;
}

int astro_body_coordinates(double et, const double state_eclipj2000[6],
                           double direction_j2000[3], double *longitude_rad,
                           double *latitude_rad, double *declination_rad,
                           double *right_ascension_rad,
                           double *longitude_rate_rad_day,
                           double *latitude_rate_rad_day,
                           double *right_ascension_rate_rad_day,
                           double *declination_rate_rad_day, char *error,
                           int error_size) {
  SpiceDouble eclipj2000_to_j2000[3][3];
  pxform_c("ECLIPJ2000", "J2000", et, eclipj2000_to_j2000);
  if (failed_c()) {
    get_cspice_error(error, error_size);
    return 0;
  }

  double position_j2000[3];
  double velocity_j2000[3];
  matrix_vector(eclipj2000_to_j2000, state_eclipj2000, position_j2000);
  matrix_vector(eclipj2000_to_j2000, state_eclipj2000 + 3, velocity_j2000);

  double norm = sqrt(position_j2000[0] * position_j2000[0] +
                     position_j2000[1] * position_j2000[1] +
                     position_j2000[2] * position_j2000[2]);
  if (norm <= 1.0e-15) {
    snprintf(error, (size_t)error_size, "%s", "degenerate direction vector");
    return 0;
  }
  for (int index = 0; index < 3; index++)
    direction_j2000[index] = position_j2000[index] / norm;

  double tt = unitim_c(et, "ET", "TDT");
  if (failed_c()) {
    get_cspice_error(error, error_size);
    return 0;
  }

  double date1 = ERFA_DJ00;
  double date2 = tt / ERFA_DAYSEC;
  double bpn[3][3];
  double bpn_before[3][3];
  double bpn_after[3][3];
  double step_seconds = 0.5;
  eraPnm06a(date1, date2, bpn);
  eraPnm06a(date1, date2 - step_seconds / ERFA_DAYSEC, bpn_before);
  eraPnm06a(date1, date2 + step_seconds / ERFA_DAYSEC, bpn_after);

  double bpn_derivative[3][3];
  matrix_derivative(bpn_after, bpn_before, step_seconds, bpn_derivative);
  double true_equatorial[3];
  double rotated_velocity[3];
  double frame_velocity[3];
  double true_equatorial_velocity[3];
  matrix_vector(bpn, position_j2000, true_equatorial);
  matrix_vector(bpn, velocity_j2000, rotated_velocity);
  matrix_vector(bpn_derivative, position_j2000, frame_velocity);
  add_vectors(rotated_velocity, frame_velocity, true_equatorial_velocity);

  double ignored_latitude;
  if (!angular_coordinates(true_equatorial, true_equatorial_velocity,
                           right_ascension_rad, &ignored_latitude,
                           right_ascension_rate_rad_day,
                           declination_rate_rad_day, error, error_size))
    return 0;
  *declination_rad = ignored_latitude;

  double dpsi;
  double deps;
  eraNut06a(date1, date2, &dpsi, &deps);
  double obliquity = eraObl06(date1, date2) + deps;
  double cosine = cos(obliquity);
  double sine = sin(obliquity);
  double true_ecliptic[3] = {
      true_equatorial[0],
      cosine * true_equatorial[1] + sine * true_equatorial[2],
      -sine * true_equatorial[1] + cosine * true_equatorial[2]};
  double true_ecliptic_velocity[3] = {
      true_equatorial_velocity[0],
      cosine * true_equatorial_velocity[1] + sine * true_equatorial_velocity[2],
      -sine * true_equatorial_velocity[1] + cosine * true_equatorial_velocity[2]};

  return angular_coordinates(true_ecliptic, true_ecliptic_velocity, longitude_rad,
                             latitude_rad, longitude_rate_rad_day,
                             latitude_rate_rad_day, error, error_size);
}

int astro_true_ecliptic_declination(double et, double longitude_rad,
                                    double latitude_rad,
                                    double *declination_rad, char *error,
                                    int error_size) {
  double tt = unitim_c(et, "ET", "TDT");
  if (failed_c()) {
    get_cspice_error(error, error_size);
    return 0;
  }

  double date1 = ERFA_DJ00;
  double date2 = tt / ERFA_DAYSEC;
  double dpsi;
  double deps;
  eraNut06a(date1, date2, &dpsi, &deps);
  double obliquity = eraObl06(date1, date2) + deps;

  *declination_rad =
      asin(sin(latitude_rad) * cos(obliquity) +
           cos(latitude_rad) * sin(obliquity) * sin(longitude_rad));
  return 1;
}
