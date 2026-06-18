#!/usr/bin/env python3

import cbor2 as cbor
import uuid
import asn1

# DER encode the PEN OID
encoder = asn1.Encoder()
encoder.start()
encoder.write('1.3.6.1.4.1', asn1.Numbers.ObjectIdentifier)
DER_PEN_OID = encoder.output()
# Strip the leading two bytes (type, length) since we are only 
# using the DER encoder to get the encoded OID.
PEN_OID = DER_PEN_OID[2:]
# Wrap in a CBOR tag
Tagged_PEN_OID = cbor.CBORTag(111,PEN_OID)
# Encode as CBOR
CBOR_PEN_OID = cbor.dumps(Tagged_PEN_OID)
# Don't have a CBOR pretty printer so do something hacky
print('~~~ cbor-pretty')
print(' '.join([f'{x:02X}' for x in CBOR_PEN_OID[:2]]))
print(f'   {CBOR_PEN_OID[2]:02X}')
print('      '+' '.join([f'{x:02X}' for x in CBOR_PEN_OID[3:]]))
print('~~~')

# Compute the UUID5 of the CBOR PEN
CBOR_PEN_UUID = uuid.uuid5(uuid.NAMESPACE_OID,CBOR_PEN_OID)

print('~~~')
print(f"NAMESPACE_CBOR_PEN = UUID5(NAMESPACE_OID, h'{CBOR_PEN_OID.hex()}')")
print(f"NAMESPACE_CBOR_PEN = {CBOR_PEN_UUID})")
print('~~~')

