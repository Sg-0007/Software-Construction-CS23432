import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/message.dart';
import '../models/scheme.dart';
import '../services/api_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/scheme_card.dart';
import '../widgets/app_drawer.dart';

class ChatScreen extends StatefulWidget {
  final Message? initialMessage;
  
  const ChatScreen({Key? key, this.initialMessage}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  List<Scheme> _currentRecommendations = [];
  List<String> _currentChips = ["🔍 Show My Schemes", "❓ How to Apply?", "🔄 Update Profile"];

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      if (widget.initialMessage!.schemes != null) {
        _currentRecommendations = widget.initialMessage!.schemes!;
      }
      _messages.add(widget.initialMessage!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.initialMessage!.schemes == null || widget.initialMessage!.schemes!.isEmpty) {
          _sendMessage("🔍 Show My Schemes", hidden: true);
        }
      });
      _scrollToBottom();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage("Hello!", hidden: true);
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text, {bool hidden = false}) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _currentChips.clear();
    });

    if (!hidden) {
      setState(() {
        _messages.add(Message(text: text, isUser: true));
      });
      _scrollToBottom();
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.sendMessage(text);
      handleApiSuccess(response);
    } catch (e) {
      setState(() {
        _messages.add(Message(
          text: e.toString(),
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void handleApiSuccess(Map<String, dynamic> response) {
    setState(() {
      List<Scheme>? renderSchemes = response['schemes'];
      if (response['command'] == 'show_schemes') {
         renderSchemes = response['schemes'];
      }
      
      if (renderSchemes != null && renderSchemes.isNotEmpty) {
        _currentRecommendations = renderSchemes;
      }
      
      String rawText = response['text'] ?? '';
      
      // Clean up stray double asterisks
      String cleanedText = rawText.replaceAll('**', '');
      // Clean up explicit "Scheme 1:" strings
      cleanedText = cleanedText.replaceAll(RegExp(r'Scheme\s*\d+:\s*', caseSensitive: false), '');
      
      _currentChips.clear();
      
      // Extract scheme names automatically from ordered lists "1. Scheme Name - Desc"
      final RegExp nameRegex = RegExp(r'^\d+\.\s+(.*?)(?=\s+-|\n|$)', multiLine: true);
      final matches = nameRegex.allMatches(cleanedText);
      for (var match in matches) {
         String name = match.group(1)?.trim() ?? '';
         if (name.isNotEmpty && name.length < 50) {
            _currentChips.add(name);
         }
      }
      
      if (cleanedText.toLowerCase().contains("quit") || cleanedText.toLowerCase().contains("exit")) {
        _currentChips.add("Quit");
      }
      
      if (_currentChips.isEmpty) {
        _currentChips = ["🔍 Show My Schemes", "❓ How to Apply?", "🔄 Update Profile"];
      }
      
      _messages.add(Message(
        text: cleanedText,
        isUser: false,
        schemes: renderSchemes,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    int totalSchemes = _messages.fold(0, (sum, m) => sum + (m.schemes?.length ?? 0));
    print('Schemes count in UI: $totalSchemes');

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          'Government Scheme Bot',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        elevation: 1,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Column(
                  children: [
                    ChatBubble(
                      message: message,
                      onSchemeTap: (query) => _sendMessage(query),
                    ),
                    if (message.schemes != null && message.schemes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
                        child: Column(
                          children: message.schemes!.map((scheme) {
                            return SchemeCard(
                              scheme: scheme,
                              onTap: () {
                                _sendMessage("show scheme ${message.schemes!.indexOf(scheme) + 1}");
                              },
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SpinKitThreeBounce(
                color: Theme.of(context).primaryColor,
                size: 20.0,
              ),
            ),
          _buildActionChips(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildActionChips() {
    if (_currentChips.isEmpty) return const SizedBox.shrink();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: _currentChips.map((label) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              label: Text(label),
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () {
                _sendMessage(label);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8.0).copyWith(bottom: MediaQuery.of(context).padding.bottom + 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (val) {
                _sendMessage(val);
                _controller.clear();
              },
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: GoogleFonts.inter(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () {
                _sendMessage(_controller.text);
                _controller.clear();
              },
            ),
          ),
        ],
      ),
    );
  }
}
