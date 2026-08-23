class EventSource {
  const EventSource({required this.name, required this.url})
    : assert(name != '');

  final String name;
  final Uri url;
}
