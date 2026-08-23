import '../domain/daily_content.dart';
import '../domain/event_image.dart';
import '../domain/event_source.dart';
import '../domain/featured_event.dart';
import '../domain/historical_event.dart';
import '../domain/historical_event_summary.dart';
import '../domain/on_this_day_repository.dart';

class FakeOnThisDayRepository implements OnThisDayRepository {
  FakeOnThisDayRepository();

  static final EventImage _bosworthImage = EventImage(
    url: Uri.parse(
      'https://upload.wikimedia.org/wikipedia/commons/2/22/'
      'Richard_III_at_the_Battle_of_Bosworth.jpg',
    ),
    altText: 'Richard III on horseback at the Battle of Bosworth Field',
    source: 'Wikimedia Commons',
    attribution:
        'Edmund Blair Leighton, Richard III at the Battle of Bosworth Field',
    creator: 'Edmund Blair Leighton',
    license: 'Public Domain Mark 1.0',
    licenseUrl: Uri.parse('https://creativecommons.org/publicdomain/mark/1.0/'),
  );

  static final DailyContent _todayContent = DailyContent(
    displayDate: 'Aug 22',
    featuredEvent: FeaturedEvent(
      id: 'battle-of-bosworth-field-1485',
      title: 'Richard III is defeated at the Battle of Bosworth Field',
      year: '1485',
      historicalDate: 'August 22, 1485',
      summary:
          'The battle ended the Wars of the Roses and brought Henry Tudor to '
          'the English throne.',
      notificationTitle: 'A king died in battle 541 years ago today',
      notificationBody:
          "Richard III's defeat at Bosworth changed England forever.",
      image: _bosworthImage,
    ),
    additionalEvents: const [
      HistoricalEventSummary(
        id: 'loch-ness-monster-columba-565',
        title: 'Saint Columba reports seeing a monster in Loch Ness',
        year: '565',
        historicalDate: 'August 22, 565',
      ),
      HistoricalEventSummary(
        id: 'cook-claims-eastern-australia-1770',
        title: 'James Cook claims eastern Australia for Britain',
        year: '1770',
        historicalDate: 'August 22, 1770',
      ),
      HistoricalEventSummary(
        id: 'venice-air-raid-1849',
        title: 'The first air raid in history is launched against Venice',
        year: '1849',
        historicalDate: 'August 22, 1849',
      ),
      HistoricalEventSummary(
        id: 'korea-annexed-by-japan-1910',
        title: 'Korea is annexed by Japan',
        year: '1910',
        historicalDate: 'August 22, 1910',
      ),
      HistoricalEventSummary(
        id: 'de-gaulle-assassination-attempt-1962',
        title: 'An assassination attempt is made on Charles de Gaulle',
        year: '1962',
        historicalDate: 'August 22, 1962',
      ),
      HistoricalEventSummary(
        id: 'nolan-ryan-5000-strikeouts-1989',
        title: 'Nolan Ryan records his 5,000th strikeout',
        year: '1989',
        historicalDate: 'August 22, 1989',
      ),
    ],
  );

  static final Map<String, HistoricalEvent> _eventsById = {
    'battle-of-bosworth-field-1485': HistoricalEvent(
      id: 'battle-of-bosworth-field-1485',
      title: 'Richard III is defeated at the Battle of Bosworth Field',
      year: '1485',
      historicalDate: 'August 22, 1485',
      summary:
          'The battle ended the Wars of the Roses and brought Henry Tudor to '
          'the English throne.',
      description:
          'On August 22, 1485, Richard III was killed at the Battle of '
          'Bosworth Field, the decisive clash that ended the Wars of the '
          'Roses. His defeat allowed Henry Tudor to become Henry VII, '
          'beginning the Tudor dynasty and reshaping English politics for '
          'generations.',
      sources: [
        EventSource(
          name: 'Encyclopaedia Britannica',
          url: Uri.parse(
            'https://www.britannica.com/event/Battle-of-Bosworth-Field',
          ),
        ),
        EventSource(
          name: 'Historic Royal Palaces',
          url: Uri.parse(
            'https://www.hrp.org.uk/tower-of-london/history-and-stories/'
            'richard-iii/',
          ),
        ),
      ],
      primaryImage: _bosworthImage,
      images: [_bosworthImage],
    ),
    'loch-ness-monster-columba-565': HistoricalEvent(
      id: 'loch-ness-monster-columba-565',
      title: 'Saint Columba reports seeing a monster in Loch Ness',
      year: '565',
      historicalDate: 'August 22, 565',
      summary:
          'An early account describes Saint Columba encountering a creature '
          'near Loch Ness.',
      description:
          'According to Adomnan of Iona, Saint Columba encountered reports of '
          'a dangerous creature near Loch Ness in 565. The story became one of '
          'the earliest written accounts connected to the later Loch Ness '
          'monster tradition.',
      sources: [
        EventSource(
          name: 'Historic UK',
          url: Uri.parse(
            'https://www.historic-uk.com/HistoryUK/HistoryofScotland/'
            'The-Loch-Ness-Monster/',
          ),
        ),
      ],
    ),
    'cook-claims-eastern-australia-1770': HistoricalEvent(
      id: 'cook-claims-eastern-australia-1770',
      title: 'James Cook claims eastern Australia for Britain',
      year: '1770',
      historicalDate: 'August 22, 1770',
      summary:
          'James Cook claimed the eastern coast of Australia for Britain as '
          'New South Wales.',
      description:
          'On August 22, 1770, James Cook claimed the eastern coast of '
          'Australia for Britain, naming it New South Wales. The act became a '
          'major step toward British colonization and had lasting consequences '
          'for Aboriginal peoples.',
      sources: [
        EventSource(
          name: 'National Museum of Australia',
          url: Uri.parse(
            'https://www.nma.gov.au/defining-moments/resources/'
            'cook-claims-australia',
          ),
        ),
      ],
    ),
    'venice-air-raid-1849': HistoricalEvent(
      id: 'venice-air-raid-1849',
      title: 'The first air raid in history is launched against Venice',
      year: '1849',
      historicalDate: 'August 22, 1849',
      summary:
          'Austrian forces used unmanned balloons carrying explosives during '
          'the siege of Venice.',
      description:
          'During the siege of Venice in 1849, Austrian forces launched '
          'unmanned balloons carrying explosives toward the city. The attack '
          'is often cited as an early example of aerial bombardment, even '
          'though wind and technology made it unreliable.',
      sources: [
        EventSource(
          name: 'Smithsonian Magazine',
          url: Uri.parse(
            'https://www.smithsonianmag.com/air-space-magazine/'
            'bombs-away-35362547/',
          ),
        ),
      ],
    ),
    'korea-annexed-by-japan-1910': HistoricalEvent(
      id: 'korea-annexed-by-japan-1910',
      title: 'Korea is annexed by Japan',
      year: '1910',
      historicalDate: 'August 22, 1910',
      summary:
          'Japan formally annexed Korea after years of expanding political '
          'and military control.',
      description:
          'On August 22, 1910, Japan and Korea signed an annexation treaty '
          'that brought Korea under Japanese colonial rule. The annexation '
          'reshaped the peninsula and remains central to modern Korean and '
          'Japanese historical memory.',
      sources: [
        EventSource(
          name: 'Encyclopaedia Britannica',
          url: Uri.parse(
            'https://www.britannica.com/place/Korea/Division-of-Korea',
          ),
        ),
      ],
    ),
    'de-gaulle-assassination-attempt-1962': HistoricalEvent(
      id: 'de-gaulle-assassination-attempt-1962',
      title: 'An assassination attempt is made on Charles de Gaulle',
      year: '1962',
      historicalDate: 'August 22, 1962',
      summary:
          'Gunmen attacked French president Charles de Gaulle near Paris, but '
          'he survived.',
      description:
          'On August 22, 1962, members of the OAS attacked Charles de '
          "Gaulle's car at Petit-Clamart near Paris. De Gaulle survived, and "
          'the failed assassination attempt became one of the most famous '
          'episodes of political violence tied to the end of French Algeria.',
      sources: [
        EventSource(
          name: 'History.com',
          url: Uri.parse(
            'https://www.history.com/this-day-in-history/de-gaulle-survives-'
            'assassination-attempt',
          ),
        ),
      ],
    ),
    'nolan-ryan-5000-strikeouts-1989': HistoricalEvent(
      id: 'nolan-ryan-5000-strikeouts-1989',
      title: 'Nolan Ryan records his 5,000th strikeout',
      year: '1989',
      historicalDate: 'August 22, 1989',
      summary:
          'Nolan Ryan became the first Major League Baseball pitcher to reach '
          '5,000 strikeouts.',
      description:
          'On August 22, 1989, Nolan Ryan struck out Rickey Henderson to '
          'record the 5,000th strikeout of his Major League Baseball career. '
          'The milestone strengthened Ryan\'s reputation as one of the most '
          'durable and overpowering pitchers in the sport.',
      sources: [
        EventSource(
          name: 'National Baseball Hall of Fame',
          url: Uri.parse(
            'https://baseballhall.org/discover-more/stories/inside-pitch/'
            'nolan-ryan-5000-strikeouts',
          ),
        ),
      ],
    ),
  };

  @override
  Future<DailyContent> getTodayContent(String timezone) async {
    return _todayContent;
  }

  @override
  Future<HistoricalEvent> getEvent(String eventId) async {
    final event = _eventsById[eventId];
    if (event == null) {
      throw EventNotFoundException(eventId);
    }

    return event;
  }
}

class EventNotFoundException implements Exception {
  const EventNotFoundException(this.eventId);

  final String eventId;

  @override
  String toString() => 'EventNotFoundException: $eventId';
}
