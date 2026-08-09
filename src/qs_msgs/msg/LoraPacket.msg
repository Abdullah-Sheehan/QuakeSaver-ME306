# Raw framed bytes handed to/from the LoRa layer.
uint8   msg_type      # 1=ENTRY 2=ANNOUNCE 3=BID 4=AWARD 5=HEARTBEAT
uint8[<=20] payload   # bounded at 20 bytes by the IDL itself
