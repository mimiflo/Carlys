# Photo d'essai : `repas-exif-gps.jpg`

Un VRAI JPEG (48 × 32 pixels, 1 982 octets), pas un tampon fabriqué dans le
test : le filtre de métadonnées (`src/common/images/jpeg-metadata.ts`) doit
être éprouvé sur des octets qu'un encodeur réel a écrits.

Il porte tout ce qu'une photo de téléphone peut divulguer :

| Segment | Contenu |
| --- | --- |
| APP0 `JFIF` | en-tête standard (gardé par le filtre) |
| APP13 `Photoshop 3.0` | IPTC, ville « Paris » |
| APP1 `Exif` | marque `Apple`, modèle `iPhone 15 Pro`, date, et un répertoire GPS : 48° 51′ 29,52″ N, 2° 17′ 40,2″ E, altitude 35 m |
| APP1 XMP | `exif:GPSLatitude` / `exif:GPSLongitude` |
| APP2 `ICC_PROFILE` | profil sRGB (gardé par le filtre) |
| COM | « Chez moi, 12 rue des Lilas » |

Engendré le 25 septembre 2026 avec Pillow 12.3 (seul l'IPTC, que Pillow
n'écrit pas, est inséré à la main après APP0). Relu par Pillow après
génération : l'EXIF GPS se relit tel quel. Après filtrage, Pillow décode les
MÊMES pixels, et ne trouve plus ni EXIF, ni XMP, ni IPTC, ni commentaire.

Pour le refaire (le profil ICC engendré porte sa date de création : un
nouveau tirage diffère de quelques octets, pas de structure) :

```python
import io, struct
from PIL import Image, ImageCms

img = Image.new('RGB', (48, 32))
px = img.load()
for y in range(32):
    for x in range(48):
        px[x, y] = (155 + x * 2 % 100, 48 + y * 3, 255 - x * 3)

exif = Image.Exif()
exif[0x010F], exif[0x0110], exif[0x0132] = 'Apple', 'iPhone 15 Pro', '2026:09:25 12:31:07'
gps = exif.get_ifd(0x8825)
gps.update({1: 'N', 2: (48.0, 51.0, 29.52), 3: 'E', 4: (2.0, 17.0, 40.2), 6: 35.0})
icc = ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
xmp = (b'<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF '
       b'xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
       b'<rdf:Description xmlns:exif="http://ns.adobe.com/exif/1.0/" '
       b'exif:GPSLatitude="48,51.492N" exif:GPSLongitude="2,17.67E"/>'
       b'</rdf:RDF></x:xmpmeta>')
buf = io.BytesIO()
img.save(buf, 'JPEG', quality=90, exif=exif, icc_profile=icc, xmp=xmp,
         comment=b'Chez moi, 12 rue des Lilas')
data = buf.getvalue()

record = b'\x1c\x02\x5a' + struct.pack('>H', 5) + b'Paris'          # IPTC 2:90, ville
resource = b'8BIM\x04\x04\x00\x00' + struct.pack('>I', len(record)) + record  # 10 octets : pair
payload = b'Photoshop 3.0\x00' + resource
app13 = b'\xff\xed' + struct.pack('>H', len(payload) + 2) + payload
cut = 4 + struct.unpack('>H', data[4:6])[0]                            # après APP0
open('repas-exif-gps.jpg', 'wb').write(data[:cut] + app13 + data[cut:])
```

Les coordonnées sont celles d'un lieu public (le Champ-de-Mars), pas d'une
personne.
