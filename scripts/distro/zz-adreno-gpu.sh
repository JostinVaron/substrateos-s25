# ZZ-ADRENO v4: todo el stack GL via Zink sobre Turnip/kgsl (Adreno 830).
# Rationale: freedreno-gallium mataba el compositor con ARGB/GTK4 (I-01);
# turnip/zink usa otro stream de comandos y ya se valido en cliente.
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export LIBGL_ALWAYS_SOFTWARE=0
export MESA_VK_WSI_PRESENT_MODE=immediate
# Nota: NO definir FD_MESA_DEBUG/FD_FORCE_KGSL/LIBGL_DRI3_DISABLE (era freedreno).
