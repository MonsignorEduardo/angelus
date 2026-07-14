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
