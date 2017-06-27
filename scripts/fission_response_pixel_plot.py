"""
Calculate fission responses for a single grid cell and plot the results
"""

import matplotlib.pyplot as plt
import numpy as np
from scripts.assemblies import shielded_assembly
import pytracer.geometry as geo
import pytracer.fission as fission


def nice_double_plot(data1, data2, extent, title1='', title2='', xlabel='', ylabel=''):
    fig = plt.figure(figsize=(8, 5))
    ax = fig.add_subplot(111)
    ax1 = fig.add_subplot(211)
    ax2 = fig.add_subplot(212)

    # Turn off axis lines and ticks of the big subplot
    ax.spines['top'].set_color('none')
    ax.spines['bottom'].set_color('none')
    ax.spines['left'].set_color('none')
    ax.spines['right'].set_color('none')
    ax.tick_params(labelcolor='w', top='off', bottom='off', left='off', right='off')

    ax1.imshow(data1, interpolation='none', extent=extent, cmap='viridis')
    ax1.set_title(title1)

    ax2.imshow(data2, interpolation='none', extent=extent, cmap='viridis')
    ax2.set_title(title2)

    ax.set_ylabel(ylabel)
    ax.set_xlabel(xlabel)
    ax.yaxis.labelpad = 40
    ax.set_frame_on(False)
    ax.axes.get_xaxis().set_ticks([])
    ax.axes.get_yaxis().set_ticks([])
    plt.subplots_adjust(right=0.98, top=0.95, bottom=0.07, left=0.12, hspace=0.05, wspace=0.20)

if __name__ == "__main__":
    assembly_solids = shielded_assembly()
    assembly_flat = geo.flatten(assembly_solids)

    # avg_nu = np.array([0.0481677, 0.2485215, 0.4253044, 0.2284094, 0.0423438, 0.0072533], dtype=np.double)
    # avg_nu = np.array([0.0084842, 0.0790030, 0.2536175, 0.3289870, 0.2328111, 0.0800161, 0.0155581, 0.0011760, 0.0003469], dtype=np.double)
    avg_nu = np.array([1.28795607e-03, 8.60279210e-01, 2.86381583e-02,
                       3.38214081e-02, 2.48722300e-02, 1.39170288e-02,
                       9.13814742e-03, 6.58515484e-03, 4.78758039e-03,
                       3.52881195e-03, 2.67774095e-03, 2.06178455e-03,
                       1.60510130e-03, 1.26381893e-03, 1.00437820e-03,
                       8.04334576e-04, 6.48533483e-04, 5.26065462e-04,
                       4.28982581e-04, 3.51465665e-04, 2.89177044e-04], dtype=np.double)
    avg_nu /= np.sum(avg_nu)

    plt.figure()
    geo.draw(assembly_solids)

    radians = np.linspace(0, np.pi, 200)
    arc_radians = np.linspace(-np.pi / 8, np.pi / 8, 200)
    source, detector_points, extent = geo.fan_beam_paths(60, arc_radians, radians, extent=True)
    source = source[0, :, :]

    grid = geo.Grid(width=25, height=15, num_x=50, num_y=30)
    grid.draw()

    cell_i = 109 * 4 - 20
    unit_m = geo.Material('black', 1, 1)
    vacuum = geo.Material('white', 0, 0)
    grid_points = grid.cell(cell_i)
    cell_geom = [geo.Solid(geo.convert_points_to_segments(grid_points, circular=True), unit_m, vacuum)]
    cell_flat = geo.flatten(cell_geom)
    plt.scatter(grid_points[:, 0], grid_points[:, 1], zorder=12)

    single_response = fission.grid_response_scan(source, detector_points, detector_points, cell_flat, assembly_flat, 1,
                                                 avg_nu)
    double_response = fission.grid_response_scan(source, detector_points, detector_points, cell_flat, assembly_flat, 2,
                                                 avg_nu)

    nice_double_plot(single_response.T, double_response.T, extent, 'Single Fission Neutron Response',
                     'Double Fission Neutron Response',
                     'Detector Orientation Angle', 'Source Neutron Direction Angle')

    plt.show()