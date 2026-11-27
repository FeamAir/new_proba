# -*- coding: utf-8 -*-
"""Этап 2 перерисовки — генерация картинок гардероба через fal.ai (nano-banana/edit + birefnet).

Не нужен игре; хранится для повторяемости. Запуск:
    python3 gen.py <id_картинки> [...]      — сгенерировать указанные (имя = ключ из SPEC)
    python3 gen.py --all                    — все, которых ещё нет
Образцы: картинка вещи, нарисованной кодом (снимок scripts/hero.gd → refs/<id>_icon.png),
и герой этапа 1 (образец стиля). Сырые картинки и снимки — во временной папке (WORK).
Каждый платный вызов записывается в cost_log.csv.
"""
import os, sys, json, time, csv, base64, urllib.request, io
from PIL import Image
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.environ.get("ART2_WORK", "/tmp/claude-0/-home-user-new-proba/49bde888-c62b-5665-865d-861c080bac27/scratchpad/art_stage2")
LOG = os.path.join(HERE, "cost_log.csv")
PRICE = {"fal-ai/nano-banana/edit": 0.0398, "fal-ai/nano-banana": 0.0398, "fal-ai/birefnet": 0.002}
LIMIT = 11.0

STYLE = ("Soft painted 3D cartoon illustration, the same rendering style as the cute character in the style "
         "reference: smooth volumetric shading, soft light from the top-left, gentle rim light, subtle painted "
         "texture, rich but soft candy colors, clean silhouette, no outline. ")
ISO = (" Show ONLY this object, alone, centered, front view, filling most of the frame, on a plain flat solid "
       "light grey background. No character, no animal, no body parts, no hands, no text, no letters, "
       "no frame, no border, no ground shadow.")

# ключ: (герой, описание, образец-снимок или None)
SPEC = {
 # ---------------- СОВЁНОК ----------------
 "owl/ow_mortarboard": ("owl", "A cute small academic graduation mortarboard cap: dark navy-blue rounded skull cap with a flat square board on top seen slightly from above, a shiny gold button in the centre and a gold cord with a fluffy gold tassel hanging down at the right corner.", "ow_mortarboard"),
 "owl/ow_halfglasses": ("owl", "Cute half-moon reading glasses: two wide half-circle lenses (flat edge on top) in a thin shiny gold frame with a small bridge, a delicate gold bead chain hanging in a loop below from both temples.", "ow_halfglasses"),
 "owl/ow_scholar_scarf": ("owl", "A cosy knitted striped scholar's scarf as worn around a neck: a short curved band wrapping around (front view, like a U shape), wide stripes of navy blue, golden yellow and burgundy, one long end hanging down on the right side with a fringe, and a small gold badge pin shaped like an open book on the band.", "ow_scholar_scarf"),
 "owl/ow_book": ("owl", "A magical flying open book with a cute little smiling face on the pages, dark red cover with gold corners, cream pages slightly fluttering, a red bookmark ribbon hanging down, tiny golden sparkles around.", "ow_book"),
 "owl/ow_quill": ("owl", "A long elegant quill feather: deep blue feather with silver-white tiny stars on the vane, curving to the upper right, its base pinned by a small golden crescent-moon brooch at the bottom.", "ow_quill"),
 "owl/ow_star_scarf": ("owl", "A soft knitted starry night scarf as worn wrapped around a neck, front view: a thick curved navy-blue band (smile-shaped arc) with small golden stars, and one long loose end hanging down and fluttering to the right whose tip dissolves into a glowing comet tail of pastel pink, lilac and gold sparkles.", None),
 "owl/ow_lantern": ("owl", "A cute little old brass watchman lantern with a round ring handle on top, warm glass panes with a glowing orange-gold flame inside, soft warm glow.", "ow_lantern"),
 "owl/ow_moth": ("owl", "A cute magical moon moth companion: soft mint-green wings with long elegant tails, lilac eye-spots on the wings, a fluffy cream body, tiny antennae and a cute small face with big shiny eyes.", "ow_moth"),
 "owl/ow_night_goggles": ("owl", "Steampunk night-vision goggles: two big round brass eyepieces with rivets, glowing mint-turquoise lenses, a dark leather strap on both sides and a small brass adjustment wheel on the bridge.", "ow_night_goggles"),
 "owl/ow_astrolabe": ("owl", "A brass star-compass medallion (astrolabe pendant) on a thin brown cord shaped like a necklace hanging in a U shape: round brass disc with engraved rings and a star-shaped needle, a small blue gem.", "ow_astrolabe"),
 "owl/ow_lorgnette": ("owl", "An elegant golden lorgnette: two round lenses with a faint lilac tint in an ornate gold frame side by side, a long thin gold handle going down from the left lens, tiny twinkling stars on the frame.", "ow_lorgnette"),
 "owl/ow_dome_hat": ("owl", "A whimsical observatory-dome hat: a rounded silver-white dome with a dark vertical slit showing tiny stars, a small brass telescope poking out diagonally from the slit to the upper right, a navy-blue brim band with a row of golden rivets.", "ow_dome_hat"),
 "owl/ow_planet": ("owl", "A cute tiny purple planet companion with a glossy pink-lilac ring around it, soft glow, a couple of tiny sparkles.", "ow_planet"),
 "owl/ow_comet": ("owl", "A LEGENDARY magical pet comet, very fancy and precious: an icy glowing round head with a cute happy face and rosy cheeks, a long sweeping iridescent tail of ice blue, lilac, pink and gold light, many twinkling stars and sparkles, radiant aura.", "ow_comet"),
 "owl/ow_stargazer_hat": ("owl", "A SUPER-EXCLUSIVE stargazer wizard hat, very fancy: a tall deep-blue cone hat with the tip curling to the side, a wide brim, embroidered with golden stars, a golden crescent moon emblem on the front, a band of gold, magical sparkles.", "ow_stargazer"),
 "owl/ow_stargazer_mantle": ("owl", "A SUPER-EXCLUSIVE stargazer's mantle cloak seen from the front as a wide flared cape spreading behind someone (the middle area plain), deep midnight-blue velvet with glowing constellation lines and stars, a golden embroidered hem, a high standing scalloped collar at the top, very fancy and magical.", None),
 # ---------------- АКСОЛОТЛЬ ----------------
 "axolotl/ax_starfish": ("axolotl", "A cute hair clip shaped like a smiling orange starfish with lighter orange dots, rosy cheeks and a tiny white pearl at one arm.", "ax_starfish"),
 "axolotl/ax_dive_mask": ("axolotl", "A cute diving mask: wide orange rubber frame around one big clear blue glass window with a shine, teal strap on both sides, a yellow snorkel standing up on the right side.", "ax_dive_mask"),
 "axolotl/ax_coral_beads": ("axolotl", "A coral bead necklace hanging in a U shape: round coral-pink and red beads, small white seashells between them, and a little branchy red coral twig as the central pendant.", "ax_coral_beads"),
 "axolotl/ax_bubble_pet": ("axolotl", "A transparent shiny soap bubble with an iridescent rim and a tiny cute orange goldfish swimming inside it.", "ax_bubble_pet"),
 "axolotl/ax_coral_tiara": ("axolotl", "A princess tiara made of branchy coral: pink and coral-red coral branches rising from a band, white pearls on the tips, an aquamarine gem in the centre.", "ax_coral_tiara"),
 "axolotl/ax_gill_pearl": ("axolotl", "A single small lustrous white-pink pearl held by a tiny ornate golden cap, like a jewel charm.", None),
 "axolotl/ax_pearls": ("axolotl", "A two-strand pearl necklace hanging in a U shape: two rows of white lustrous pearls with a bigger pink pearl in a small golden cap in the centre.", "ax_pearls"),
 "axolotl/ax_shell_pack": ("axolotl", "A cute backpack shaped like a big pink pearly scallop seashell with ribs, iridescent sheen, a small pearl latch.", "ax_shell_pack"),
 "axolotl/ax_shell_straps": ("axolotl", "Two short shoulder straps made of strung white pearls, symmetrical, left and right, slightly curved like straps going over shoulders, with a small pink shell clasp on each.", None),
 "axolotl/ax_black_pearl": ("axolotl", "A thin silver chain necklace hanging in a U shape with one big glossy black pearl pendant with a teal-turquoise sheen, in a small silver cap.", "ax_black_pearl"),
 "axolotl/ax_porthole": ("axolotl", "Porthole goggles: two round thick brass rings with bolts around them, joined by a short bridge, greenish-aqua glass with tiny bubbles inside.", "ax_porthole"),
 "axolotl/ax_angler": ("axolotl", "An anglerfish lure headpiece: a thin pink curved stalk rising up and bending over forward, with a glowing mint-green light ball at its tip, soft glow.", "ax_angler"),
 "axolotl/ax_squid": ("axolotl", "A cute little pink-lilac squid companion with big shiny eyes, a pointed mantle with fins, wavy tentacles and small glowing spots.", "ax_squid"),
 "axolotl/ax_seahorse": ("axolotl", "A LEGENDARY golden seahorse guardian companion, very fancy: shining gold seahorse with a cute face, a tiny crown-like crest, pearly fins, curled tail, glowing aura and sparkles.", "ax_seahorse"),
 "axolotl/ax_wave_cape": ("axolotl", "A LEGENDARY sea-wave cape seen from the front as a wide flared cape spreading behind someone (the middle area plain): turquoise translucent fin-like fabric with fin rays, a wavy foamy edge like a sea wave, pearls and glimmering sparkles, very fancy.", "ax_wave_cape"),
 "axolotl/ax_wave_clasp": ("axolotl", "A small fancy cape clasp: a pearly turquoise scallop shell brooch with a pearl, with two short turquoise fabric bands going left and right.", None),
 "axolotl/ax_abyssal_crown": ("axolotl", "A SUPER-EXCLUSIVE pearl crown, very fancy: a band of white pearls with small pearl spires and in the centre a big glowing pearl emitting turquoise-blue deep-sea light, tiny bioluminescent sparkles.", "ax_abyssal"),
 # ---------------- ЩЕНОК ----------------
 "puppy/pu_cap": ("puppy", "A cute red baseball cap seen from the front, white front panel with a red paw-print emblem, the visor turned slightly to the side.", "pu_cap"),
 "puppy/pu_whistle": ("puppy", "A coach's silver whistle hanging on a blue cord shaped like a U necklace.", "pu_whistle"),
 "puppy/pu_visor": ("puppy", "Sporty wrap-around sunglasses with one wide curved shield lens with a gradient from orange through pink to purple, a white frame, reflections.", "pu_visor"),
 "puppy/pu_ball": ("puppy", "A bright yellow-green fuzzy tennis ball with the white curved seam.", "pu_ball"),
 "puppy/pu_daisy_wreath": ("puppy", "A flower wreath of white daisies with yellow centres and small green leaves on a green vine, seen from the front as worn on a head (a wide arc).", "pu_daisy_wreath"),
 "puppy/pu_flower_scarf": ("puppy", "A light-blue triangle neckerchief as worn around a neck, front view, decorated with small white daisies, tied in a little knot at the side.", "pu_flower_scarf"),
 "puppy/pu_daisy_specs": ("puppy", "Funny round glasses where each lens is the yellow centre of a big white daisy flower: round lenses with a yellow frame, white petals all around each lens, a yellow bridge.", "pu_daisy_specs"),
 "puppy/pu_basket": ("puppy", "A small wicker picnic basket with a handle, a red-white checked cloth and a fresh bun peeking out.", "pu_basket"),
 "puppy/pu_bolt_band": ("puppy", "A blue sports headband seen from the front as a curved band with a yellow lightning bolt emblem in the middle, two short ribbon tails fluttering on the right.", "pu_bolt_band"),
 "puppy/pu_hero_bandana": ("puppy", "A red triangle bandana as worn around a neck, front view, with small golden stars, a knot at the side.", "pu_hero_bandana"),
 "puppy/pu_jetpack": ("puppy", "A cute toy jetpack: two red-and-white rockets with round blue windows standing upright side by side joined by a small grey harness pack, little orange-yellow flames from the nozzles.", "pu_jetpack"),
 "puppy/pu_jetpack_straps": ("puppy", "Two simple symmetrical red-and-white striped shoulder straps, left and right, slightly curved, like backpack straps seen from the front, each with a small silver buckle.", None),
 "puppy/pu_robo": ("puppy", "A cute round little robot buddy: white glossy round body, a dark screen face with glowing cyan happy eyes, a tiny antenna with a red ball, a small propeller, little side ear-discs.", "pu_robo"),
 "puppy/pu_frisbee": ("puppy", "A LEGENDARY golden frisbee disc, very fancy: shining gold with concentric rings and a star emblem, a rainbow light trail sweeping behind it, sparkles and a glow.", "pu_frisbee"),
 "puppy/pu_hero_mask": ("puppy", "A SUPER-EXCLUSIVE superhero eye mask: bright blue mask with two large eye holes, pointed tips at the sides, a golden edge, glossy, heroic.", "pu_hero"),
 "puppy/pu_hero_medal": ("puppy", "A SUPER-EXCLUSIVE gold hero medal with a star emblem hanging on a red-and-white striped ribbon shaped like a U necklace, shiny, sparkles.", None),
 "puppy/pu_hero_cape": ("puppy", "A SUPER-EXCLUSIVE superhero cape seen from the front as a wide red cape spreading behind someone (the middle area plain), flowing in the wind, a golden trim, a golden paw emblem on one side, heroic and fancy.", None),
 # ---------------- КОТИК ----------------
 "kitten/ki_pompom_hat": ("kitten", "A cosy knitted beanie: pink with white horizontal stripes, a folded white rib-knit cuff, a big fluffy white pom-pom on top.", "ki_pompom_hat"),
 "kitten/ki_bell_bow": ("kitten", "A soft red cat collar with white stitching shaped like a U, a small ring and a shiny golden jingle bell hanging in the centre.", "ki_bell_bow"),
 "kitten/ki_yarn": ("kitten", "A cute ball of lavender-pink yarn with visible wrapped threads, two knitting needles crossed through it, a loose thread end curling.", "ki_yarn"),
 "kitten/ki_sweater": ("kitten", "A cute cropped knitted lavender sweater front, short and round like for a chubby little toy body: a rolled turtleneck collar on top, cable-knit pattern, a row of small pink hearts, ribbed hem; no sleeves visible.", "ki_sweater"),
 "kitten/ki_sleuth_hat": ("kitten", "A detective deerstalker cap: tan-brown plaid tweed, front and back visors, small ear flaps tied up on top with a button.", "ki_sleuth_hat"),
 "kitten/ki_moustache": ("kitten", "A big bushy chestnut-brown handlebar moustache with tips curled upward, soft fluffy texture.", "ki_moustache"),
 "kitten/ki_sleuth_badge": ("kitten", "A golden shield detective badge with an embossed magnifying glass, hanging on a brown leather cord shaped like a U necklace.", "ki_sleuth_badge"),
 "kitten/ki_trench": ("kitten", "A short khaki detective trench coat seen from the front as a wide coat spreading behind someone (the middle chest area hidden/plain), belt ends, buttons along the edges, ending at the hem.", "ki_trench"),
 "kitten/ki_trench_collar": ("kitten", "The collar and lapels of a khaki trench coat, front view: two wide pointed lapels forming a V shape with a couple of buttons below, nothing else.", None),
 "kitten/ki_magnifier": ("kitten", "A magnifying glass with a shiny gold rim and a wooden handle, a little paw print visible through the lens.", "ki_magnifier"),
 "kitten/ki_masquerade": ("kitten", "A masquerade eye mask: purple velvet wings around two eye holes, gold trim with tiny pearls, colourful feathers (pink, mint) on the top right.", "ki_masquerade"),
 "kitten/ki_cameo": ("kitten", "A black velvet ribbon choker shaped like a U with a pink oval cameo showing a white cat silhouette in an ornate gold frame with a small pearl drop.", "ki_cameo"),
 "kitten/ki_feather_hat": ("kitten", "A tiny tilted purple velvet top hat with a black net veil, a big fluffy pink feather and a green gem on the band.", "ki_feather_hat"),
 "kitten/ki_ball_cloak": ("kitten", "A ballroom cloak seen from the front as a wide flared cloak spreading behind someone (the middle area plain): deep purple velvet with a silver embroidered trim and a tall standing collar.", "ki_ball_cloak"),
 "kitten/ki_ball_clasp": ("kitten", "A small elegant cloak clasp: a silver brooch with a lilac gem and two short purple velvet cords going left and right.", None),
 "kitten/ki_teacup": ("kitten", "A LEGENDARY little porcelain teacup companion, very fancy: white-pink fine porcelain with a gold rim and gold handle, a cute smiling face with rosy cheeks, on a small saucer, pink heart-shaped steam rising, sparkles.", "ki_teacup"),
 "kitten/ki_starry_tiara": ("kitten", "A SUPER-EXCLUSIVE silver tiara, very fancy: delicate silver filigree with small stars, a big sparkling iridescent crystal in the centre, glowing.", "ki_starry"),
 "kitten/ki_starry_crown": ("kitten", "A SUPER-EXCLUSIVE golden star crown, very fancy: a golden band with three tall pointed rays like star points, small stars, a big violet crystal in the centre, glowing sparkles.", "ki_starry"),
}

# иконки сияний (только для карточек; сами сияния — частицы в коде)
AURA = {
 "owl/ow_aura_starfall": ("owl", "Icon: a shower of falling golden and white shooting stars with sparkly trails, diagonal."),
 "owl/ow_page_whirl": ("owl", "Icon: very ornate and precious, magic whirlwind of old book pages with glowing golden runes swirling in a circle, sparkles."),
 "owl/ow_stargazer": ("owl", "Icon: the most precious and ornate emblem: a deep-blue starry wizard hat with a gold crescent moon, tiny planets orbiting around it on golden orbit lines, rich glow."),
 "axolotl/ax_aura_bubbles": ("axolotl", "Icon: a cluster of shiny iridescent soap bubbles of different sizes rising."),
 "axolotl/ax_plankton": ("axolotl", "Icon: very ornate and precious, two swirling spirals of tiny glowing plankton dots in turquoise, pink and gold, like a dancing galaxy."),
 "axolotl/ax_abyssal": ("axolotl", "Icon: the most precious and ornate: three cute glowing jellyfish lanterns in turquoise, pink and violet around a glowing pearl, deep-sea glow."),
 "puppy/pu_petal_rainbow": ("puppy", "Icon: very ornate and precious, a small pastel rainbow arc with white daisy petals and little daisies floating around."),
 "puppy/pu_aura_bolts": ("puppy", "Icon: very ornate and precious, crackling yellow lightning bolts with speed lines, energetic."),
 "puppy/pu_hero": ("puppy", "Icon: the most precious and ornate emblem: a red flowing hero cape behind a golden star medal with a paw print, golden stars."),
 "kitten/ki_clue_trail": ("kitten", "Icon: very ornate and precious, a trail of small paw prints leading to golden question marks, a warm flashlight beam glow."),
 "kitten/ki_aura_fireworks": ("kitten", "Icon: very ornate and precious, pastel festive fireworks bursts in pink, lilac and gold."),
 "kitten/ki_starry": ("kitten", "Icon: the most precious and ornate emblem: a silver tiara with a crystal and a golden star crown side by side, surrounded by glowing butterflies and little comets."),
}
AURA_ISO = (" A compact game icon composition of the effect only, centered, filling most of the frame, with bright "
            "saturated glowing colours, on a plain flat solid light grey background. No character, no animal, no words, "
            "no letters, no numbers, no text at all, no frame, no border, no rounded square, no badge.")


def spent():
    if not os.path.exists(LOG):
        return 0.0
    with open(LOG) as f:
        return sum(float(r["est_usd"]) for r in csv.DictReader(f))


def log(model, name, note):
    new = not os.path.exists(LOG)
    with open(LOG, "a", newline="") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["time", "model", "file", "est_usd", "note"])
        w.writerow([time.strftime("%Y-%m-%d %H:%M:%S"), model, name, PRICE[model], note])


def call(model, payload):
    if spent() + PRICE[model] > LIMIT:
        raise SystemExit("ЛИМИТ: траты подошли к $%.2f" % LIMIT)
    req = urllib.request.Request(f"https://queue.fal.run/{model}", data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    r = json.load(urllib.request.urlopen(req, timeout=120))
    st, rs = r["status_url"], r["response_url"]
    for _ in range(300):
        s = json.load(urllib.request.urlopen(st, timeout=60))
        if s["status"] == "COMPLETED":
            break
        time.sleep(2)
    return json.load(urllib.request.urlopen(rs, timeout=120))


def datauri(p):
    return "data:image/png;base64," + base64.b64encode(open(p, "rb").read()).decode()


def fetch(url):
    return Image.open(io.BytesIO(urllib.request.urlopen(url, timeout=120).read()))


def trim(im, pad=6):
    a = np.array(im)[:, :, 3]
    ys, xs = np.where(a > 8)
    box = (max(0, xs.min() - pad), max(0, ys.min() - pad), min(im.width, xs.max() + pad + 1), min(im.height, ys.max() + pad + 1))
    return im.crop(box)


def make(key, tag=""):
    hero = key.split("/")[0]
    if key in SPEC:
        _, desc, ref = SPEC[key]
        prompt = STYLE + desc + ISO
        urls = []
        if ref:
            urls.append(datauri(f"{WORK}/refs/{ref}_icon.png"))
            prompt = ("The first image is a simple flat game sketch of the object: keep its shape, colours and idea, "
                      "but redraw it as a high quality illustration. The second image is only a STYLE reference. ") + prompt
        else:
            prompt = "The image is only a STYLE reference. " + prompt
        urls.append(datauri(f"{WORK}/inp/style_{hero}.png"))
        note = "item"
    else:
        _, desc = AURA[key]
        prompt = "The image is only a STYLE reference. " + STYLE + desc + AURA_ISO
        urls = [datauri(f"{WORK}/inp/style_{hero}.png")]
        note = "aura icon"
    name = key.replace("/", "_") + tag
    out = call("fal-ai/nano-banana/edit", {"prompt": prompt, "image_urls": urls, "num_images": 1, "output_format": "png"})
    log("fal-ai/nano-banana/edit", name + ".png", note)
    raw = fetch(out["images"][0]["url"]).convert("RGB")
    os.makedirs(f"{WORK}/raw", exist_ok=True)
    rawp = f"{WORK}/raw/{name}.png"
    raw.save(rawp)
    cut = call("fal-ai/birefnet", {"image_url": datauri(rawp), "output_format": "png"})
    log("fal-ai/birefnet", name + ".png", "bg removal")
    im = fetch(cut["image"]["url"]).convert("RGBA")
    im = trim(im)
    dst = os.path.join(HERE, key + tag + ".png")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    im.save(dst)
    return dst


if __name__ == "__main__":
    args = sys.argv[1:]
    tag = ""
    if args and args[0].startswith("--tag="):
        tag = args.pop(0)[6:]
    if args == ["--all"]:
        keys = [k for k in list(SPEC) + list(AURA) if not os.path.exists(os.path.join(HERE, k + ".png"))
                and not os.path.exists(f"{WORK}/raw/{k.replace('/', '_')}.png")]
    else:
        keys = args
    from concurrent.futures import ThreadPoolExecutor
    def job(k):
        try:
            return k, make(k, tag)
        except SystemExit as e:
            return k, str(e)
        except Exception as e:
            return k, "ERR " + repr(e)
    with ThreadPoolExecutor(6) as ex:
        for k, r in ex.map(job, keys):
            print(k, "->", r, flush=True)
    print("spent $%.3f" % spent())
