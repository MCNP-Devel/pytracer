cimport cython

from libc.math cimport floor, ceil, sqrt, pow, acos, fabs, M_PI, exp, atan2, fmod, sin, cos
import numpy as np
cimport numpy as np

cpdef unsigned int binom(unsigned int n, unsigned int k):
    cdef:
        unsigned int ans=1
        unsigned int j=1

    if k > n - k:
        k = n - k

    for j in range(1, k+1):
        if n % j == 0:
            ans *= n / j
        elif ans % j == 0:
            ans = ans / j * n
        else:
            ans = (ans * n) / j
        n -= 1

    return ans


cpdef c_line_box_overlap_line(double[::1] line, double ex1, double ex2, double ey1, double ey2):
    cdef:
        int p1_inside = -1
        int p2_inside = -1
        double lx1, ly1, lx2, ly2
        double dl, dr, db, dt
        double tl, tr, tb, tt
        double ul, ur, ub, ut
        int n_ts = 0


    # test if first point in image
    if ex1 <= line[0] <= ex2 and ey1 <= line[1] <= ey2:
        p1_inside = 1
    else:
        p1_inside = -1

    # test if second point in image
    if ex1 <= line[2] <= ex2 and ey1 <= line[3] <= ey2:
        p2_inside = 1
    else:
        p2_inside = -1

        ts1 = 2.
    ts2 = 2.

    # left side
    dl = (line[0] - line[2]) * (ey1 - ey2) - (line[1] - line[3]) * (ex1 - ex1)
    if dl != 0:
        tl = (line[0] - ex1) * (ey1 - ey2) - (line[1] - ey1) * (ex1 - ex1)
        ul = - (line[0] - line[2]) * (line[1] - ey1) + (line[1] - line[3]) * (line[0] - ex1)
        tl /= dl
        ul /= dl
        if 0 <= ul < 1 and 0 <= tl <= 1:
            ts2 = ts1
            ts1 = tl
    # tl, ul = line_line_intersection_parametric(line[0], line[1], line[2], line[3], ex1, ey1, ex1, ey2)
    # right side
    dr = (line[0] - line[2]) * (ey1 - ey2) - (line[1] - line[3]) * (ex2 - ex2)
    if dr != 0:
        tr = (line[0] - ex2) * (ey1 - ey2) - (line[1] - ey1) * (ex2 - ex2)
        ur = - (line[0] - line[2]) * (line[1] - ey1) + (line[1] - line[3]) * (line[0] - ex2)
        tr /= dr
        ur /= dr
        if 0 <= ur < 1 and 0 <= tr <= 1:
            ts2 = ts1
            ts1 = tr
    # tr, ur = line_line_intersection_parametric(line[0], line[1], line[2], line[3], ex2, ey1, ex2, ey2)
    # bottom side
    db = (line[0] - line[2]) * (ey1 - ey1) - (line[1] - line[3]) * (ex1 - ex2)
    if db != 0:
        tb = (line[0] - ex1) * (ey1 - ey1) - (line[1] - ey1) * (ex1 - ex2)
        ub = - (line[0] - line[2]) * (line[1] - ey1) + (line[1] - line[3]) * (line[0] - ex1)
        tb /= db
        ub /= db
        if 0 <= ub < 1 and 0 <= tb <= 1:
            ts2 = ts1
            ts1 = tb
    # tb, ub = line_line_intersection_parametric(line[0], line[1], line[2], line[3], ex1, ey1, ex2, ey1)
    # top side
    dt = (line[0] - line[2]) * (ey2 - ey2) - (line[1] - line[3]) * (ex1 - ex2)
    if dt != 0:
        tt = (line[0] - ex1) * (ey2 - ey2) - (line[1] - ey2) * (ex1 - ex2)
        ut = - (line[0] - line[2]) * (line[1] - ey2) + (line[1] - line[3]) * (line[0] - ex1)
        tt /= dt
        ut /= dt
        if 0 <= ut < 1 and 0 <= tt <= 1:
            ts2 = ts1
            ts1 = tt

    if 0 <= ts1 <= 1:
        n_ts += 1
    if 0 <= ts2 <= 1:
        n_ts += 1

    lx1 = line[0]
    ly1 = line[1]
    lx2 = line[2]
    ly2 = line[3]

    if n_ts == 0 and p1_inside == 1 and p2_inside == 1:
        return
    elif n_ts == 1 and p1_inside == 1:
        line[2] = lx1 + ts1 * (lx2 - lx1)
        line[3] = ly1 + ts1 * (ly2 - ly1)
    elif n_ts == 1 and p2_inside == 1:
        line[2] = lx1
        line[3] = ly1
        line[0] = lx1 + ts1 * (lx2 - lx1)
        line[1] = ly1 + ts1 * (ly2 - ly1)
    elif n_ts == 2 and p1_inside != 1 and p2_inside != 1:
        line[0] = lx1 + ts1 * (lx2 - lx1)
        line[1] = ly1 + ts1 * (ly2 - ly1)
        line[2] = lx1 + ts2 * (lx2 - lx1)
        line[3] = ly1 + ts2 * (ly2 - ly1)

    return


cpdef double c_bilinear_interpolation(double x, double y, double[:, ::1] pixels, double ex1, double ex2, double ey1,
                                      double ey2):
    """
    NOTE: ASSUMES PIXELS IS ZERO PADDED
    a ---- b
    | x    |
    |      |
    c ---- d
    """
    cdef:
        double delx
        double dely
        int i1, j1, i2, j2
        double x1, y1
        double t, u
        double interp

    delx = (ex2 - ex1) / pixels.shape[1]
    dely = (ey2 - ey1) / pixels.shape[0]

    if x < (ex1 + delx / 2.) or x >= (ex2 - delx / 2.):
        return 0
    if y < (ey1 + dely / 2.) or y >= (ey2 - dely / 2.):
        return 0

    # get index of lower left corner
    i1 = int(floor((x - ex1 - delx / 2.) / (ex2 - ex1 - delx) * (pixels.shape[1] - 1)))
    j1 = int(floor((y - ey1 - dely / 2.) / (ey2 - ey1 - dely) * (pixels.shape[0] - 1)))
    i2 = i1 + 1
    j2 = j1 + 1

    x1 = ex1 + delx / 2. + i1 * delx
    y1 = ey1 + dely / 2. + j1 * dely

    t = (x - x1) / delx
    u = (y - y1) / dely

    interp = (1 - t) * (1 - u) * pixels[j1, i1] + \
        t * (1 - u) * pixels[j1, i2] + \
        t * u * pixels[j2, i2] + \
        (1 - t) * u * pixels[j2, i1]

    return interp


cpdef double c_raytrace_bilinear(double[::1] line, double ex1, double ex2, double ey1, double ey2, double[:, ::1] pixels,
                                 double step_size=1e-3):
    # NOTE: pixels MUST be zero padded!
    # will have innacurate results otherwise
    cdef:
        double line_distance
        double bli_start, bli_end
        double integral
        int n_steps
        double step
        double bli_prev, bli_next
        int i
        double pos_x, pos_y

    c_line_box_overlap_line(line, ex1, ex2, ey1, ey2)

    line_distance = sqrt((line[2] - line[0])**2 + (line[3] - line[1])**2)

    if line_distance == 0:
        return 0.

    bli_start = c_bilinear_interpolation(line[0], line[1], pixels, ex1, ex2, ey1, ey2)
    bli_end = c_bilinear_interpolation(line[2], line[3], pixels, ex1, ex2, ey1, ey2)

    if line_distance < 2 * step_size:
        return (bli_start + bli_end) / 2 * line_distance

    integral = 0
    n_steps = int(floor(line_distance / step_size))
    step = line_distance / n_steps

    bli_prev = bli_start
    bli_next = 0.

    for i in range(n_steps - 1):
        pos_x = line[0] + (i+1) * (line[2] - line[0]) / n_steps
        pos_y = line[1] + (i+1) * (line[3] - line[1]) / n_steps

        bli_next = c_bilinear_interpolation(pos_x, pos_y, pixels, ex1, ex2, ey1, ey2)
        integral += (bli_prev + bli_next)
        bli_prev = bli_next

    integral += (bli_prev + bli_end)

    return integral * (line_distance / n_steps / 2)


cpdef double c_raytrace_bulk_bilinear(double[:, ::1] lines, double ex1, double ex2, double ey1, double ey2,
                                      double[:, ::1] pixels, double[::1] sinogram, double step_size=1e-3):
    cdef:
        int i

    for i in range(lines.shape[0]):
        sinogram[i] = c_raytrace_bilinear(lines[i], ex1, ex2, ey1, ey2, pixels, step_size)


cpdef double interp1d(double[::1] xs, double[::1] ys, double xnew, double left=0, double right=0) except? -1:
    cdef:
        unsigned int index, index_left, index_right
        double prev_distance = 1e10
        double distance
        double ynew

    if xs[0] < xs[-1]:
        if xnew < xs[0]:
            return left
        elif xnew > xs[-1]:
            return right

        for i in range(xs.shape[0]):
            distance = xnew - xs[i]
            if distance < prev_distance and distance >= 0:
                index_left = i
                index_right = i+1
                prev_distance = distance
    else:
        if xnew > xs[0]:
            return left
        elif xnew < xs[-1]:
            return right

        for i in range(xs.shape[0]):
            distance = xs[i] - xnew
            if distance < prev_distance and distance >= 0:
                index_left = i
                index_right = i+1
                prev_distance = distance

    ynew = ys[index_left] + (ys[index_right] - ys[index_left]) * (xnew - xs[index_left]) / (xs[index_right] - xs[index_left])

    return ynew


cpdef double pixel_coord_to_radian(unsigned int i, unsigned int j, unsigned int nx, unsigned int ny,
                                   double ex1, double ex2, double ey1, double ey2, double source_x, double source_y):
    cdef:
        double dx, dy
        double center_x, center_y
        double value

    dx = (ex2 - ex1) / nx
    dy = (ey2 - ey1) / ny

    center_x = ex1 + (i + 0.5) * dx
    center_y = ey1 + (j + 0.5) * dy

    value = atan2(center_y - source_y, center_x - source_x) - atan2(-source_y, -source_x)
    value = fmod(value + 2 * M_PI, 2 * M_PI)

    return value


cpdef double pixel_coord_to_ss(unsigned int i, unsigned int j, unsigned int nx, unsigned int ny,
                                double ex1, double ex2, double ey1, double ey2, double radian):
    cdef:
        double dx, dy
        double center_x, center_y
        double value

    dx = (ex2 - ex1) / nx
    dy = (ey2 - ey1) / ny

    center_x = ex1 + (i + 0.5) * dx
    center_y = ey1 + (j + 0.5) * dy

    value = center_x * cos(radian) + center_y * sin(radian)

    return value


cpdef void c_backproject_fan(double[::1] radians, double[::1] sinogram, double source_x, double source_y,
                               double ex1, double ex2, double ey1, double ey2, double[:, ::1] pixels):
    cdef:
        unsigned int i, j
        double pixel_radian

    for j in range(pixels.shape[0]):
        for i in range(pixels.shape[1]):
            pixel_radian = pixel_coord_to_radian(i, j, pixels.shape[1], pixels.shape[0], ex1, ex2, ey1, ey2, source_x, source_y)
            pixels[j, i] += interp1d(radians, sinogram, pixel_radian, 0, 0)


cpdef void c_backproject_parallel(double radian, double[::1] ss, double[::1] sinogram, double ex1, double ex2, double ey1,
                                  double ey2, double[:, ::1] pixels):
    cdef:
        unsigned int i, j
        double pixel_ss

    for j in range(pixels.shape[0]):
        for i in range(pixels.shape[1]):
            pixel_ss = pixel_coord_to_ss(i, j, pixels.shape[1], pixels.shape[0], ex1, ex2, ey1, ey2, radian)
            pixels[j, i] += interp1d(ss, sinogram, pixel_ss, 0, 0)


# Fission stuff
cpdef double solid_angle(double lx1, double ly1, double lx2, double ly2, double px, double py):
    cdef:
        double a, b, c, num, denom, angle

    a = (lx1 - px) * (lx1 - px) + (ly1 - py) * (ly1 - py)
    b = (lx2 - px) * (lx2 - px) + (ly2 - py) * (ly2 - py)
    c = (lx1 - lx2) * (lx1 - lx2) + (ly1 - ly2) * (ly1 - ly2)

    num = a + b - c
    denom = 2 * sqrt(a) * sqrt(b)
    angle = acos(fabs(num / denom))
    if angle > M_PI / 2.:
        angle = M_PI - angle

    return angle


cpdef double exit_probability(double p, unsigned int k, double[::1] nu_dist, double detector_prob):
    cdef:
        double exit_prob = 0.
        unsigned int i

    for i in range(nu_dist.shape[0]):
        exit_prob += binom(i, k) * nu_dist[i] * pow(detector_prob, k) * pow(1. - detector_prob, i - k)

    return exit_prob


cpdef detect_probability(double[::1] point, double[:, ::1] image, double ex1, double ex2, double ey1, double ey2,
                         double[:, ::1] detector_points, double step_size=1e-3):

    cdef:
        double detector_prob = 0
        unsigned int i
        double detector_center_x, detector_center_y
        double exit_absorbance
        double exit_prob
        double solid_angle_prob
        np.ndarray exit_ray = np.zeros(4, dtype=np.double)

    exit_ray[0] = point[0]
    exit_ray[1] = point[1]

    for i in range(detector_points.shape[0]-1):

        detector_center_x = (detector_points[i, 0] + detector_points[i+1, 0]) / 2.
        detector_center_y = (detector_points[i, 1] + detector_points[i+1, 1]) / 2.

        exit_ray[2] = detector_center_x
        exit_ray[3] = detector_center_y

        exit_absorbance = c_raytrace_bilinear(exit_ray, ex1, ex2, ey1, ey2, image, step_size)
        exit_prob = exp(-exit_absorbance)

        solid_angle_prob = solid_angle(detector_points[i, 0], detector_points[i, 1],
                                       detector_points[i+1, 0], detector_points[i+1, 1],
                                       point[0], point[1])

        detector_prob += exit_prob * solid_angle_prob

    return detector_prob


cpdef double fission_probability(double[::1] line, unsigned int k, double[:, ::1] mu_image, double[:, ::1] mu_f_image,
                                 double[:, ::1] p_image, double[::1] extent, double[:, ::1] detector_points,
                                 double[::1] nu_dist, double step_size=1e-3):
    cdef:
        double ex1, ex2, ey1, ey2
        double line_distance
        double fission_prob_integral = 0
        double absorbance_in = 0
        unsigned int n_steps
        double step
        np.ndarray pos = np.zeros(2, np.double)
        double mu, mu_f, p
        double fission_prob_prev = 0.
        double enter_prob, detector_prob, exit_prob, mu_prev

    # assumes rays originate outside of image boundaries defined by extent
    ex1, ex2, ey1, ey2 = extent

    c_line_box_overlap_line(line, ex1, ex2, ey1, ey2)

    line_distance = sqrt((line[2] - line[0]) ** 2 + (line[3] - line[1]) ** 2)
    if line_distance == 0:
        return 0.

    n_steps = max(int(floor(line_distance / step_size)), 2)
    step = line_distance / n_steps
    pos[0] = line[0]
    pos[1] = line[1]

    mu = c_bilinear_interpolation(pos[0], pos[1], mu_f_image, ex1, ex2, ey1, ey2)
    mu_f = c_bilinear_interpolation(pos[0], pos[1], mu_f_image, ex1, ex2, ey1, ey2)
    p = c_bilinear_interpolation(pos[0], pos[1], p_image, ex1, ex2, ey1, ey2)
    if mu <= 0 or mu_f <= 0 or p <= 0:
        fission_prob_prev = 0
    else:
        absorbance_in += 0.

        enter_prob = exp(-absorbance_in)
        detector_prob = detect_probability(pos, mu_image, ex1, ex2, ey1, ey2, detector_points, step_size)
        exit_prob = exit_probability(p, k, nu_dist, detector_prob)

        mu_prev = mu
        fission_prob_prev = enter_prob * mu_f * exit_prob

    for i in range(n_steps - 1):
        pos[0] = line[0] + (i+1) * (line[2] - line[0]) / n_steps
        pos[1] = line[1] + (i+1) * (line[3] - line[1]) / n_steps

        mu = c_bilinear_interpolation(pos[0], pos[1], mu_image, ex1, ex2, ey1, ey2)
        if mu <= 0:
            mu_prev = 0
            continue
        mu_f = c_bilinear_interpolation(pos[0], pos[1], mu_f_image, ex1, ex2, ey1, ey2)
        if mu_f <= 0:
            continue
        p = c_bilinear_interpolation(pos[0], pos[1], p_image, ex1, ex2, ey1, ey2)
        if p <= 0:
            continue

        absorbance_in += (mu_prev + mu) * (line_distance / n_steps / 2)

        enter_prob = exp(-absorbance_in)
        detector_prob = detect_probability(pos, mu_image, *extent, detector_points, step_size)
        exit_prob = exit_probability(p, k, nu_dist, detector_prob)

        fission_prob = enter_prob * mu_f * exit_prob

        fission_prob_integral += (fission_prob + fission_prob_prev) * (line_distance / n_steps / 2)

        mu_prev = mu
        fission_prob_prev = fission_prob

    return fission_prob_integral