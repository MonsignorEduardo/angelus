#ifndef ANGELUS_ASTRO_FRAMES_H
#define ANGELUS_ASTRO_FRAMES_H

int astro_true_ecliptic_coordinates(double et,
                                     const double position_eclipj2000[3],
                                     double *longitude_rad,
                                     double *latitude_rad,
                                     double *declination_rad, char *error,
                                     int error_size);

int astro_body_coordinates(double et, const double state_eclipj2000[6],
                           double direction_j2000[3], double *longitude_rad,
                           double *latitude_rad, double *declination_rad,
                           double *right_ascension_rad,
                           double *longitude_rate_rad_day,
                           double *latitude_rate_rad_day,
                           double *right_ascension_rate_rad_day,
                           double *declination_rate_rad_day, char *error,
                           int error_size);

int astro_true_ecliptic_declination(double et, double longitude_rad,
                                    double latitude_rad,
                                    double *declination_rad, char *error,
                                    int error_size);

#endif /* ANGELUS_ASTRO_FRAMES_H */
