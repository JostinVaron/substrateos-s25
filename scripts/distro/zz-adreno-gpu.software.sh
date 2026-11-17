# ZZ-ADRENO software - escape hatch (GNOME49_SW=1).
# Estado dorado previo: compositor estable en CPU (llvmpipe/swrast).
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export MESA_LOADER_DRIVER_OVERRIDE=swrast
export LIBGL_DRI3_DISABLE=1
