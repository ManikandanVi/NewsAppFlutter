/// The data layer of the app: the Article model, JSON parsing, and a
/// bundled fallback dataset used when the live API can't be reached.
library;

/// One news story.
///
/// A model class is just a plain Dart class that mirrors the shape of the
/// data we care about. We only take the fields the UI actually shows
/// (title, image, summary, ...) and ignore the rest of the API response.
class Article {
  Article({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.summary,
    required this.newsSite,
    required this.publishedAt,
    required this.url,
  });

  final String id;
  final String title;
  final String imageUrl;
  final String summary;
  final String newsSite; // e.g. "NASA", "ESA", "Spaceflight Now"
  final DateTime publishedAt;
  final String url; // link to the original article on the source's site

  /// Builds an [Article] from the JSON map the Spaceflight News API sends
  /// for one element of its `results` array.
  ///
  /// JSON gives us dynamic values, so every field needs a cast. Coalescing
  /// with `??` keeps one malformed field from crashing the whole feed.
  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: (json['id'] ?? 0).toString(),
      title: (json['title'] ?? 'Untitled').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      newsSite: (json['news_site'] ?? 'Unknown').toString(),
      // The API sends ISO-8601 (e.g. "2026-10-05T12:00:00Z").
      // tryParse returns null for bad input, so fall back to "now"
      // instead of crashing on a malformed date.
      publishedAt: DateTime.tryParse((json['published_at'] ?? '').toString()) ??
          DateTime.now(),
      url: (json['url'] ?? '').toString(),
    );
  }

  /// Shortens the summary for list cards so a long paragraph doesn't
  /// overflow the layout. "…" is added only when we actually trimmed.
  String get shortSummary {
    final s = summary.trim();
    if (s.length <= 140) return s;
    final cut = s.substring(0, 140);
    // trimRight() trims trailing whitespace (trimEnd isn't a String method).
    return '${cut.trimRight()}…';
  }
}

/// A hand-written dataset used as fallback when the API is unreachable
/// (offline, API down, corporate proxy...). Every image URL here was
/// verified to load, and Unsplash sends CORS headers, so they work on
/// Flutter web as well as Android.
///
/// It's `final` rather than `const` because the entries carry a real
/// DateTime (DateTime has no const constructor). The published times here
/// are just placeholders — [getFallbackArticles] re-stamps them with
/// believable, staggered times at startup.
final fallbackArticles = <Article>[
  Article(
    id: 'fb-1',
    title: 'JWST peers into the Sombrero Galaxy to trace its tidal streams',
    imageUrl:
        'https://images.unsplash.com/photo-1444703686981-a3abbc4d4fe3'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'Astronomers used the James Webb Space Telescope to map faint tidal '
        'streams around the Sombrero Galaxy (M104), revealing a history of '
        'galactic mergers written in the motion of its outer stars. The '
        'observations help settle a long debate over whether the galaxy is '
        'a true elliptical or an unusually massive spiral.',
    newsSite: 'NASA',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://science.nasa.gov',
  ),
  Article(
    id: 'fb-2',
    title: 'Artemis II crew rehearses launch-day countdown procedures',
    imageUrl:
        'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'The four astronauts assigned to the first crewed Orion lunar '
        'mission ran a full countdown simulation inside the Orion '
        'spacecraft, practising every step from suit-up to orbit insertion. '
        'NASA says the test marks a major milestone on the road to sending '
        'humans around the Moon again.',
    newsSite: 'NASA',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://www.nasa.gov/artemis',
  ),
  Article(
    id: 'fb-3',
    title: 'SpaceX completes static fire of Super Heavy booster ahead of next flight',
    imageUrl:
        'https://images.unsplash.com/photo-1541185933-ef5d8ed016c2'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'SpaceX fired up its most powerful booster at Starbase, Texas, '
        'briefly igniting all engines while the vehicle was held down. '
        'Teams will now review the data ahead of the next integrated '
        'Starship test flight, which is expected to attempt a catch of the '
        'booster with the launch tower arms.',
    newsSite: 'SpaceX',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://www.spacex.com',
  ),
  Article(
    id: 'fb-4',
    title: 'ESA greenlights the ExoMars rover for a 2028 launch window',
    imageUrl:
        'https://images.unsplash.com/photo-1451187580459-43490279c0fa'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'European Space Agency member states confirmed funding for the '
        'ExoMars Rosalind Franklin rover, which will drill two metres into '
        'the Martian surface searching for signs of past life. The launch '
        'window opens in 2028, with landing planned for the following year.',
    newsSite: 'ESA',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://www.esa.int',
  ),
  Article(
    id: 'fb-5',
    title: 'Meteor shower peaks this week under moonless skies',
    imageUrl:
        'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'Skywatchers can catch up to 60 meteors per hour as Earth passes '
        'through a debris stream left by a long-period comet. With the Moon '
        'near new, conditions are ideal: find a dark spot away from city '
        'lights, let your eyes adapt for 20 minutes, and look up.',
    newsSite: 'Sky & Telescope',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://skyandtelescope.org',
  ),
  Article(
    id: 'fb-6',
    title: 'Orbital telescope spots a rare planet being born',
    imageUrl:
        'https://images.unsplash.com/photo-1502134249126-9f3755a50d78'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'Astronomers directly imaged a young planet still embedded in the '
        'dusty disc around its parent star. The observations capture the '
        'planet in the act of forming, feeding on spirals of gas, and give '
        'scientists a rare window into how our own solar system may have '
        'assembled billions of years ago.',
    newsSite: 'Space Telescope',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://webbtelescope.org',
  ),
  Article(
    id: 'fb-7',
    title: 'New cargo mission delivers supplies and experiments to the ISS',
    imageUrl:
        'https://images.unsplash.com/photo-1462331940025-496dfbfc7564'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'A robotic cargo spacecraft docked with the International Space '
        'Station carrying food, water and more than two tonnes of science '
        'experiments, including a study of bone loss in microgravity and a '
        'student-built radiation sensor. The station crew unloaded it '
        'within hours of capture.',
    newsSite: 'Spaceflight Now',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://spaceflightnow.com',
  ),
  Article(
    id: 'fb-8',
    title: 'Night launch lights up the coast as satellite cluster reaches orbit',
    imageUrl:
        'https://images.unsplash.com/photo-1464802686167-b939a6910659'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'Dozens of small satellites reached low Earth orbit after a '
        'spectacular after-dark launch visible for miles. The cluster will '
        'raise its orbit over the coming weeks before starting its Earth '
        'observation mission, returning imagery for climate and disaster '
        'researchers.',
    newsSite: 'Spaceflight Now',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://spaceflightnow.com',
  ),
  Article(
    id: 'fb-9',
    title: 'Rocket Lab prepares first flight of its larger Neutron rocket',
    imageUrl:
        'https://images.unsplash.com/photo-1516849841032-87cbac4d88f7'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'Rocket Lab confirmed the debut flight of Neutron, its medium-lift, '
        'reusable rocket designed for satellite constellations and future '
        'interplanetary missions. The company says the first stage will '
        'return to the launch site for a propulsive landing like Falcon 9.',
    newsSite: 'Rocket Lab',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://www.rocketlabusa.com',
  ),
  Article(
    id: 'fb-10',
    title: 'Lunar south pole missions target the permanently shadowed craters',
    imageUrl:
        'https://images.unsplash.com/photo-1457364887197-9150188c107b'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'Several landers will attempt to explore craters near the lunar '
        'south pole, where sunlight never reaches the floor and water ice '
        'may have survived for billions of years. Proving the ice exists — '
        'and can be mined — would reshape plans for a permanent Moon base.',
    newsSite: 'ESA',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://www.esa.int',
  ),
  Article(
    id: 'fb-11',
    title: 'Voyager 1 keeps transmitting from interstellar space after fixes',
    imageUrl:
        'https://images.unsplash.com/photo-1454789548928-9efd52dc4031'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'Engineers coaxed the 47-year-old Voyager 1 spacecraft back to full '
        'data transmission after months of troubleshooting its failing '
        'computers. It remains the farthest human-made object, sending '
        'signals from beyond the edge of the solar system that take over '
        '22 hours to reach Earth.',
    newsSite: 'NASA JPL',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://www.jpl.nasa.gov',
  ),
  Article(
    id: 'fb-12',
    title: 'Total solar eclipse draws scientists and skywatchers worldwide',
    imageUrl:
        'https://images.unsplash.com/photo-1508739773434-c26b3d09e071'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'Millions gathered along the path of totality as the Moon fully '
        'covered the Sun for several minutes. Researchers used the rare '
        'alignment to study the Sun\'s corona and test instruments destined '
        'for future space telescopes.',
    newsSite: 'Sky & Telescope',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://skyandtelescope.org',
  ),
  Article(
    id: 'fb-13',
    title: 'Europa Clipper returns first test images during cruise to Jupiter',
    imageUrl:
        'https://images.unsplash.com/photo-1610296669228-602fa827fc1f'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'The Europa Clipper spacecraft checked out its cameras and '
        'instruments during the long cruise to Jupiter, returning starfield '
        'test images. When it arrives, the probe will fly close to Europa '
        'repeatedly to map the ice shell and the ocean suspected beneath it.',
    newsSite: 'NASA JPL',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://www.jpl.nasa.gov',
  ),
  Article(
    id: 'fb-14',
    title: 'Chandra observes a black hole shredding a passing star',
    imageUrl:
        'https://images.unsplash.com/photo-1620712943543-bcc4688e7485'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'X-ray observatories watched a supermassive black hole tear apart a '
        'star that drifted too close, producing a flare visible across '
        'half the observable universe. Tidal disruption events like this '
        'reveal how black holes grow and how matter behaves at the edge '
        'of an event horizon.',
    newsSite: 'Chandra',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://chandra.harvard.edu',
  ),
  Article(
    id: 'fb-15',
    title: 'Saturn ring probe mission extended through the next decade',
    imageUrl:
        'https://images.unsplash.com/photo-1457364559154-aa2644600ebb'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'Mission managers approved a multi-year extension for the orbiter '
        'studying Saturn\'s rings, allowing scientists to keep measuring '
        'how the rings age and dissipate. Recent data suggests the rings '
        'are younger than the planet itself and may vanish within a few '
        'hundred million years.',
    newsSite: 'NASA',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://www.nasa.gov',
  ),
  Article(
    id: 'fb-16',
    title: 'Starliner test crew returns safely after extended stay',
    imageUrl:
        'https://images.unsplash.com/photo-1446941611757-91d2c3bd3d45'
        '?auto=format&fit=crop&w=900&q=70',
    summary:
        'The two NASA astronauts who flew the first crewed Starliner test '
        'flight returned to Earth aboard a Dragon capsule after their '
        'vehicle was deemed unsafe for the trip home. NASA says the '
        'extended stay turned into valuable long-duration data for future '
        'missions.',
    newsSite: 'Spaceflight Now',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0),
    url: 'https://spaceflightnow.com',
  ),
];

/// The fallback list is declared `const`, so every entry must be a compile-
/// time constant — meaning `publishedAt: DateTime.now()` is illegal there.
/// This wrapper walks the list once at startup and stamps each article
/// with a fake "recently published" time (staggered by a few hours so the
/// feed looks natural).
List<Article> getFallbackArticles() {
  final now = DateTime.now();
  return [
    for (var i = 0; i < fallbackArticles.length; i++)
      Article(
        id: fallbackArticles[i].id,
        title: fallbackArticles[i].title,
        imageUrl: fallbackArticles[i].imageUrl,
        summary: fallbackArticles[i].summary,
        newsSite: fallbackArticles[i].newsSite,
        publishedAt: now.subtract(Duration(hours: i * 5 + 2)),
        url: fallbackArticles[i].url,
      ),
  ];
}
