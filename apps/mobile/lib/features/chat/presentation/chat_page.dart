// Re-export ChatHubPage as ChatPage for router compatibility
export 'chat_hub_page.dart' show ChatHubPage;

// Alias: the router currently uses `const ChatPage()`, so keep the name
import 'chat_hub_page.dart';

/// Chat hub page — alias for [ChatHubPage] to match existing router usage.
typedef ChatPage = ChatHubPage;
