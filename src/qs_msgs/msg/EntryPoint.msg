# A candidate rubble entry point detected by a UAV.
# Wire format: 15 bytes over LoRa.
uint8  src_id         # originating agent (1=uav1, 2=uav2)
uint16 point_id       # unique per src_id
int32  lat_e7         # latitude  in degrees * 1e7
int32  lon_e7         # longitude in degrees * 1e7
uint8  confidence     # 0-100, from detector scoring
uint16 width_cm       # estimated opening width
uint8  hazard_flags   # bitfield, reserved
