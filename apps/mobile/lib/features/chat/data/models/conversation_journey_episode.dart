/// Presentation metadata for a scene whose playable content comes from the API.
class ConversationJourneyEpisode {
  const ConversationJourneyEpisode({
    required this.number,
    required this.scenarioId,
    required this.title,
    required this.goals,
    required this.place,
    required this.keywords,
    required this.examples,
    required this.meanings,
    this.estimatedMinutes = 3,
    this.hubDescription,
  });

  final int number;
  final String scenarioId;
  final String title;
  final List<String> goals;
  final int estimatedMinutes;
  final String place;
  final String? hubDescription;
  final List<String> keywords;
  final List<String> examples;
  final List<String> meanings;

  int estimatedMinutesWithFallback(int? scenarioMinutes) {
    return scenarioMinutes != null && scenarioMinutes > 0
        ? scenarioMinutes
        : estimatedMinutes;
  }

  String descriptionWithFallback(String? scenarioDescription) {
    final description = scenarioDescription?.trim() ?? '';
    return hubDescription ??
        (description.isNotEmpty ? description : goals.firstOrNull ?? '');
  }
}

const tokyoFirstDayTitle = '도쿄에서의 첫날';

const tokyoFirstDayEpisodes = [
  ConversationJourneyEpisode(
    number: 1,
    scenarioId: '7089ccbe-53d2-5263-a1be-a6975a2d4072',
    title: '공항에서 시내행 열차표 사기',
    place: '공항 매표소',
    hubDescription: '공항 매표소에서 신주쿠까지 가는 열차를 물어보고 표 한 장을 사요.',
    goals: ['시내행 열차편 묻기', '목적지를 말하고 표 요청하기'],
    keywords: ['新宿・電車', '新宿・切符'],
    examples: ['新宿へはどの電車に乗ればいいですか。', '新宿までの切符を一枚お願いします。'],
    meanings: ['신주쿠에 가려면 어떤 열차를 타야 하나요?', '신주쿠까지 가는 표 한 장 주세요.'],
  ),
  ConversationJourneyEpisode(
    number: 2,
    scenarioId: '2f7cb48b-ff67-505b-99d7-a6a140a186b1',
    title: '체크인 전 짐 맡기기',
    place: '호텔 프런트',
    goals: ['체크인 시작 시간 묻기', '짐을 맡길 수 있는지 묻기'],
    keywords: ['チェックイン・何時から', '荷物・預ける'],
    examples: ['チェックインは何時からですか。', '荷物を預けてもいいですか。'],
    meanings: ['체크인은 몇 시부터예요?', '짐을 맡겨도 될까요?'],
  ),
  ConversationJourneyEpisode(
    number: 3,
    scenarioId: '6f9ca02c-e97e-5bfe-b0fd-43b6332b0e6c',
    title: '카페에서 테이크아웃',
    place: '동네 카페',
    goals: ['아이스 커피 한 잔 주문하기', '포장으로 부탁하기'],
    keywords: ['アイスコーヒー・一つ', '持ち帰り'],
    examples: ['アイスコーヒーを一つお願いします。', '持ち帰りでお願いします。'],
    meanings: ['아이스 커피 하나 주세요.', '포장으로 부탁합니다.'],
  ),
];

ConversationJourneyEpisode? tokyoFirstDayEpisodeFor(String? scenarioId) {
  for (final episode in tokyoFirstDayEpisodes) {
    if (episode.scenarioId == scenarioId) return episode;
  }
  return null;
}

bool isTokyoFirstDayScenario(String? scenarioId) =>
    tokyoFirstDayEpisodeFor(scenarioId) != null;
