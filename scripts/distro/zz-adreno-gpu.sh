# ZZ-ADRENO: receta GPU transplantada (MISION-TRASPLANTE-V3)
export LIBGL_ALWAYS_SOFTWARE=0
export GALLIUM_DRIVER=freedreno
export MESA_LOADER_DRIVER_OVERRIDE=kgsl
export FD_FORCE_KGSL=1
# Adreno 830: evitar el fallo de LRZ al componer superficies ARGB/GTK4.
export FD_MESA_DEBUG=nolrz
export LIBGL_DRI3_DISABLE=1
