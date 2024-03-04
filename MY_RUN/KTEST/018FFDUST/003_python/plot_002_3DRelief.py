#!/usr/bin/env python3
"""
@author: Quentin Rodier
Creation : 07/01/2021

Last modifications
"""
import matplotlib as mpl
mpl.use('Agg')
from read_MNHfile import read_netcdf
from Panel_Plot import PanelPlot
from misc_functions import comp_altitude2DVar
import os

os.system('rm -f tempgraph*')
#
#  User's parameter / Namelist
#
path=""

LnameFiles = ['REL3D.1.EXP01.002.nc']

Dvar_input = {'f1':['ZS', 'UT', 'WT','ni_u','nj_u','level','ZTOP', 'ni','nj','level_w','time']}

#  Read the variables in the files
Dvar = {}
Dvar = read_netcdf(LnameFiles, Dvar_input, path=path, removeHALO=True)

# Compute altitude variable in 3D with a 2D topography
Dvar['f1']['altitude'], Dvar['f1']['ni_u_3D'],  Dvar['f1']['nj_u_3D'] = comp_altitude2DVar(Dvar['f1']['UT'], Dvar['f1']['ZS'],Dvar['f1']['ZTOP'], Dvar['f1']['level'], Dvar['f1']['ni_u'], Dvar['f1']['nj_u'])
Dvar['f1']['altitude_w'], Dvar['f1']['ni_3D'], Dvar['f1']['nj_3D'] = comp_altitude2DVar(Dvar['f1']['WT'], Dvar['f1']['ZS'],Dvar['f1']['ZTOP'], Dvar['f1']['level_w'],Dvar['f1']['ni'], Dvar['f1']['nj'])

orog = Dvar['f1']['ZS'][15,:]

################################################################
#########          PANEL 1
###############################################################
Panel1 = PanelPlot(2,2, [20,20],'003_2DRelief vertical and horizontal sections')

Lplot = [ Dvar['f1']['UT'][:,15,:], Dvar['f1']['WT'][:,15,:]]
LaxeX = [Dvar['f1']['ni_u_3D'][:,15,:], Dvar['f1']['ni_3D'][:,15,:]]
LaxeZ = [Dvar['f1']['altitude'][:,15,:], Dvar['f1']['altitude_w'][:,15,:]]
Ltitle = ['u-wind UT', 'Vertical velocity WT',]
Lcbarlabel = ['m/s']*len(Lplot)
Lxlab = ['x (m)']*len(Lplot)
Lylab = ['altitude (m)']*len(Lplot)
Lylim = [(0,10000.1)]*len(Lplot)
Lminval = [8, -1.2]
Lmaxval = [14, 0.9]
Lstep = [0.25, 0.1]
Lstepticks = Lstep
Lcolormap = ['gist_rainbow_r']*len(Lplot)
Ltime = [Dvar['f1']['time']]*len(Lplot)
fig1 = Panel1.psectionV(Lxx=LaxeX, Lzz=LaxeZ, Lvar=Lplot, Lxlab=Lxlab, Lylab=Lylab, Ltitle=Ltitle, Lminval=Lminval, Lmaxval=Lmaxval, 
                                Lstep=Lstep, Lstepticks=Lstepticks, Lcolormap=Lcolormap, Lcbarlabel=Lcbarlabel,
                                orog=orog, Lylim=Lylim, colorbar=True, Ltime=Ltime)

# Horizontal cross-section
Lplot = [ Dvar['f1']['UT'], Dvar['f1']['WT']]
Ltitle = ['u-wind UT at K=2', 'Vertical velocity WT at K=2',]
LaxeX = [Dvar['f1']['ni_u'], Dvar['f1']['ni']]
LaxeY = [Dvar['f1']['nj_u'], Dvar['f1']['nj']]
Llvl = [0]*len(Lplot)

fig2 = Panel1.psectionH(lon=LaxeX, lat=LaxeY, Lvar=Lplot, Llevel=Llvl, Lxlab=Lxlab, Lylab=Lylab, Ltitle=Ltitle, Lminval=Lminval, Lmaxval=Lmaxval, 
                                Lstep=Lstep, Lstepticks=Lstepticks, Lcolormap=Lcolormap, Lcbarlabel=Lcbarlabel, 
                                colorbar=True, Ltime=Ltime, ax=fig1.axes)

Panel1.save_graph(1,fig2)
