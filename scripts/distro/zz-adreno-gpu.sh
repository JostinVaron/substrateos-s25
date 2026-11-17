# ZZ-ADRENO v4: todo el stack GL via Zink sobre Turnip/kgsl (Adreno 830).
# Rationale: freedreno-gallium mataba el compositor con ARGB/GTK4 (I-01);
# turnip/zink usa otro stream de comandos y ya se valido en cliente.
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export LIBGL_ALWAYS_SOFTWARE=0
export MESA_VK_WSI_PRESENT_MODE=immediate
# Nota: NO definir FD_MESA_DEBUG/FD_FORCE_KGSL/LIBGL_DRI3_DISABLE (era freedreno).
# Fix definitivo I-11 (apps invisibles): sin DRI3, el TFP de zink no puede
# importar los pixmaps del servidor; mutter lee las ventanas por CPU (XGetImage)
# y compone igual. Verificado RMSE=0 pixel-exacto, damage vivo, idle 0% CPU.
export COGL_DISABLE_TFP=1
