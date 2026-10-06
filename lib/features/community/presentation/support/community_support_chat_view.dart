import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';
import '../../../auth/domain/account_role.dart';
import '../../../auth/state/auth_provider.dart';
import '../providers/support_chat_provider.dart';

/// Meetday Support Chat screen matching the web dashboard MeetdayChatPanel.
/// Provides direct concierge communication with the Meetday admin and bot team.
class CommunitySupportChatView extends ConsumerStatefulWidget {
  const CommunitySupportChatView({super.key});

  @override
  ConsumerState<CommunitySupportChatView> createState() => _CommunitySupportChatViewState();
}

class _CommunitySupportChatViewState extends ConsumerState<CommunitySupportChatView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  Timer? _pollTimer;
  Timer? _highlightTimer;

  bool _isSending = false;
  bool _showEmojiPicker = false;
  String? _editingMessageId;
  SupportChatMessage? _replyingTo;
  String? _highlightedMessageId;
  int _prevMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Poll support messages every 4 seconds, matching POLL_MS on the website
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        ref.invalidate(supportChatMessagesProvider);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _highlightTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool smooth = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (smooth) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _jumpToMessage(String messageId, List<SupportChatMessage> messages) {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1 && _scrollController.hasClients) {
      final total = messages.length;
      final maxExtent = _scrollController.position.maxScrollExtent;
      final estimatedOffset = (index / (total > 1 ? total - 1 : 1)) * maxExtent;
      _scrollController.animateTo(
        estimatedOffset.clamp(0.0, maxExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      _highlightTimer?.cancel();
      setState(() {
        _highlightedMessageId = messageId;
      });
      _highlightTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    }
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final api = ref.read(apiClientProvider);

    // Edit flow
    if (_editingMessageId != null) {
      final msgId = _editingMessageId!;
      setState(() {
        _isSending = true;
      });
      try {
        await editSupportChatMessageApi(api, msgId, text);
        _textController.clear();
        setState(() {
          _editingMessageId = null;
        });
        ref.invalidate(supportChatMessagesProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to edit message: $e', style: GoogleFonts.poppins(fontSize: 12)),
              backgroundColor: MeetdayColors.primaryRed,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSending = false;
          });
        }
      }
      return;
    }

    // Normal send flow
    setState(() {
      _isSending = true;
    });

    final replyId = _replyingTo?.id;

    final role = ref.read(authControllerProvider).role;
    final contextParam = role == AccountRole.brand
        ? 'BRAND'
        : (role == AccountRole.space ? 'SPACE' : 'HOST');

    try {
      final res = await sendSupportChatMessageApi(
        api,
        content: text,
        replyToId: replyId,
        context: contextParam,
      );

      _textController.clear();
      setState(() {
        _replyingTo = null;
      });

      ref.invalidate(supportChatMessagesProvider);
      _scrollToBottom();

      if (res?.wasRedacted == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
            content: Row(
              children: [
                const Icon(Icons.shield_outlined, color: MeetdayColors.accentYellow, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Phone numbers, emails, and IDs aren't allowed here — we've masked them to keep things safe.",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e', style: GoogleFonts.poppins(fontSize: 12)),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _handleStartEdit(SupportChatMessage m) {
    setState(() {
      _replyingTo = null;
      _editingMessageId = m.id;
      _textController.text = m.content;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: m.content.length),
      );
    });
    _focusNode.requestFocus();
  }

  void _handleCancelEdit() {
    setState(() {
      _editingMessageId = null;
      _textController.clear();
    });
  }

  Future<void> _handleDelete(SupportChatMessage m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.black, width: 2.5),
        ),
        backgroundColor: Colors.white,
        title: Text(
          'Delete Message?',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        content: Text(
          "Are you sure you want to delete this message? This can't be undone.",
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MeetdayColors.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.black, width: 1.5),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final api = ref.read(apiClientProvider);
    try {
      await deleteSupportChatMessageApi(api, m.id);
      if (_editingMessageId == m.id) {
        _handleCancelEdit();
      }
      ref.invalidate(supportChatMessagesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete message: $e', style: GoogleFonts.poppins(fontSize: 12)),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    }
  }

  void _showAttachmentSheet() {
    final urlController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Colors.black, width: 2.5),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Attach Media',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter an image or screenshot URL to share with Meetday Support.',
              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                ],
              ),
              child: TextField(
                controller: urlController,
                style: GoogleFonts.poppins(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'https://images.unsplash.com/...',
                  hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MeetdayColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Colors.black, width: 2),
                  ),
                ),
                onPressed: () async {
                  final url = urlController.text.trim();
                  if (url.isEmpty) return;
                  Navigator.pop(ctx);

                  setState(() => _isSending = true);
                  final role = ref.read(authControllerProvider).role;
                  final contextParam = role == AccountRole.brand
                      ? 'BRAND'
                      : (role == AccountRole.space ? 'SPACE' : 'HOST');
                  try {
                    final api = ref.read(apiClientProvider);
                    await sendSupportChatMessageApi(
                      api,
                      content: '',
                      mediaUrl: url,
                      replyToId: _replyingTo?.id,
                      context: contextParam,
                    );
                    setState(() => _replyingTo = null);
                    ref.invalidate(supportChatMessagesProvider);
                    _scrollToBottom();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to send image: $e', style: GoogleFonts.poppins(fontSize: 12)),
                          backgroundColor: MeetdayColors.primaryRed,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isSending = false);
                    }
                  }
                },
                child: Text(
                  'Send Attachment',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageLightbox(String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 200,
                  color: Colors.white,
                  child: Center(
                    child: Text('Unable to load image', style: GoogleFonts.poppins(fontSize: 12)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
                    ],
                  ),
                  child: const Icon(Icons.close_rounded, size: 20, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(supportChatMessagesProvider);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subheader matching DashboardSupportPage
          Text(
            'Support Chat',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Chat directly with the Meetday team.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 10),

          // Main Neo-Brutalist Chat Panel
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black, width: 2.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Inner Panel Header: "Talk to Meetday"
                  _buildPanelHeader(),

                  // Message List
                  Expanded(
                    child: messagesAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
                      ),
                      error: (err, stack) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: MeetdayColors.primaryRed, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              'Unable to load support chat',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MeetdayColors.accentYellow,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: Colors.black, width: 1.5),
                                ),
                              ),
                              onPressed: () => ref.invalidate(supportChatMessagesProvider),
                              child: Text('Retry', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                      data: (messages) {
                        if (messages.length != _prevMessageCount) {
                          _prevMessageCount = messages.length;
                          _scrollToBottom();
                        }

                        if (messages.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: MeetdayColors.accentYellow.withAlpha(50),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 2),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.chat_bubble_outline_rounded, size: 26, color: Colors.black),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No messages yet — say hi to the Meetday team!',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final m = messages[index];
                            return _buildMessageItem(m, messages);
                          },
                        );
                      },
                    ),
                  ),

                  // Editing Banner
                  if (_editingMessageId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        border: Border(top: BorderSide(color: Colors.black, width: 2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 14, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            'EDITING MESSAGE',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.black54,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _handleCancelEdit,
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MeetdayColors.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Replying Banner
                  if (_replyingTo != null && _editingMessageId == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        border: Border(top: BorderSide(color: Colors.black, width: 2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3.5,
                            height: 28,
                            decoration: BoxDecoration(
                              color: MeetdayColors.primaryRed,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'REPLYING TO ${_replyingTo!.senderType == "ADMIN" ? "ADMIN" : _replyingTo!.senderType == "BOT" ? "MEETDAY" : "YOU"}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black45,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  _replyingTo!.content.isNotEmpty
                                      ? _replyingTo!.content
                                      : (_replyingTo!.mediaUrl != null ? 'Photo' : ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _replyingTo = null),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MeetdayColors.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Bottom Composer
                  _buildComposer(),

                  // Emoji picker drawer
                  if (_showEmojiPicker) _buildEmojiPicker(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Inner Panel Header ────────────────────────────────────────────────────

  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black, width: 2.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Talk to Meetday',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "Questions, issues, or feedback? We're here to help.",
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),

          // Online pill indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.black, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Online',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // Refresh button
          GestureDetector(
            onTap: () => ref.invalidate(supportChatMessagesProvider),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                ],
              ),
              child: const Icon(Icons.refresh_rounded, size: 16, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Message Item Builder ──────────────────────────────────────────────────

  Widget _buildMessageItem(SupportChatMessage m, List<SupportChatMessage> allMessages) {
    // 1. System messages
    if (m.isSystem) {
      final text = m.content.replaceFirst(RegExp(r'^\[System\]\s*', caseSensitive: false), '');
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black12, width: 1),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
      );
    }

    final isBrand = ref.watch(authControllerProvider).role == AccountRole.brand;
    final isMine = m.isMine;
    final isBot = m.isBot;
    final isHighlighted = _highlightedMessageId == m.id;
    final senderLabel = isMine ? 'YOU' : (isBot ? 'MEETDAY' : 'ADMIN');

    final timeString = m.createdAt != null
        ? DateFormat('hh:mm a').format(m.createdAt!)
        : '';

    final isRedBubble = isMine && isBrand;
    final bubbleColor = isMine
        ? (isBrand ? MeetdayColors.primaryRed : MeetdayColors.accentYellow)
        : const Color(0xFFF3F4F6);
    final contentTextColor = isRedBubble ? Colors.white : const Color(0xFF111111);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: isHighlighted
          ? BoxDecoration(
              color: MeetdayColors.accentYellow.withAlpha(40),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MeetdayColors.primaryRed, width: 2),
            )
          : null,
      padding: isHighlighted ? const EdgeInsets.all(4) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Header Label & Action buttons
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.black45,
                  ),
                ),
                if (!m.isDeleted) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _editingMessageId = null;
                        _replyingTo = m;
                      });
                      _focusNode.requestFocus();
                    },
                    child: Text(
                      'Reply',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                ],
                if (isMine && !m.isDeleted && m.content.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _handleStartEdit(m),
                    child: Text(
                      'Edit',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                ],
                if (isMine && !m.isDeleted) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _handleDelete(m),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: MeetdayColors.primaryRed,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Message Bubble
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                // Sent by brand: RED; Sent by others: Yellow; Received: Grey
                color: bubbleColor,
                borderRadius: isMine
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(4),
                      )
                    : const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                        bottomLeft: Radius.circular(4),
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Replying snippet preview inside bubble
                  if (m.replyTo != null)
                    GestureDetector(
                      onTap: () => _jumpToMessage(m.replyTo!.id, allMessages),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isRedBubble
                              ? Colors.black.withAlpha(50)
                              : Colors.black.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isRedBubble
                                  ? Colors.white
                                  : (isMine ? Colors.black.withAlpha(120) : MeetdayColors.primaryRed),
                              width: 3.5,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '↩ Replying to ${m.replyTo!.senderType == "ADMIN" ? "Admin" : m.replyTo!.senderType == "BOT" ? "Meetday" : "You"}',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isRedBubble
                                    ? Colors.white.withAlpha(220)
                                    : Colors.black87,
                              ),
                            ),
                            if (m.replyTo!.hasMedia)
                              Text(
                                '📷 Photo',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isRedBubble ? Colors.white : Colors.black87,
                                ),
                              ),
                            if (m.replyTo!.content.isNotEmpty)
                              Text(
                                m.replyTo!.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: isRedBubble ? Colors.white : Colors.black87,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Deleted message indicator
                  if (m.isDeleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFECACA), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🗑️', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 4),
                          Text(
                            'This message was deleted',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Image attachment if any
                  if (m.mediaUrl != null && m.mediaUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        onTap: () => _showImageLightbox(m.mediaUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 1.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Image.network(
                              m.mediaUrl!,
                              fit: BoxFit.cover,
                              width: 180,
                              height: 140,
                              errorBuilder: (_, _, _) => Container(
                                width: 180,
                                height: 80,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.broken_image_rounded, size: 28, color: Colors.black38),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Message content text
                  if (m.content.isNotEmpty)
                    SelectableText(
                      m.content,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: contentTextColor,
                        height: 1.35,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Message Footer: Timestamp, Edited status, Checkmarks
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 4, left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timeString.isNotEmpty)
                  Text(
                    timeString,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.black38,
                    ),
                  ),
                if (m.isEdited && !m.isDeleted) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(edited)',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: Colors.black38,
                    ),
                  ),
                ],
                if (isMine) ...[
                  const SizedBox(width: 3),
                  const Text(
                    '✓✓',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black38,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Composer ──────────────────────────────────────────────────────────────

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black, width: 2.5)),
      ),
      child: Row(
        children: [
          // Media attachment button
          GestureDetector(
            onTap: _isSending ? null : _showAttachmentSheet,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                ],
              ),
              child: const Center(
                child: Icon(Icons.attach_file_rounded, size: 18, color: Colors.black87),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Emoji button
          GestureDetector(
            onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _showEmojiPicker ? MeetdayColors.accentYellow : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                ],
              ),
              child: const Center(
                child: Icon(Icons.emoji_emotions_outlined, size: 18, color: Colors.black87),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                ],
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: _editingMessageId != null
                      ? 'Edit your message…'
                      : 'Write a message… (type @ to tag)',
                  hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black38),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Send / Save Button
          GestureDetector(
            onTap: _isSending ? null : _handleSend,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _editingMessageId != null
                    ? MeetdayColors.accentYellow
                    : MeetdayColors.primaryRed,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                ],
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_editingMessageId != null) ...[
                          Text(
                            'Save',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ] else ...[
                          const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Emoji Picker Grid ─────────────────────────────────────────────────────

  Widget _buildEmojiPicker() {
    const emojis = [
      '👍', '❤️', '🔥', '🎉', '🚀', '👏', '🤝', '✨', '💯', '🙌',
      '😊', '😂', '🤣', '😍', '🤔', '😎', '🥳', '🤩', '💡', '💬',
      '📅', '📍', '🏢', '💼', '📈', '💰', '🏷️', '🎯', '🎤', '☕',
      '⭐', '📌', '🏆', '✅', '🔔', '📣', '🍻', '🍔', '🍕', '🎈',
    ];

    return Container(
      height: 160,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        border: Border(top: BorderSide(color: Colors.black, width: 2)),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          final emoji = emojis[index];
          return InkWell(
            onTap: () {
              final text = _textController.text;
              final selection = _textController.selection;
              final newText = selection.start >= 0
                  ? text.replaceRange(selection.start, selection.end, emoji)
                  : text + emoji;
              _textController.text = newText;
              _textController.selection = TextSelection.collapsed(
                offset: (selection.start >= 0 ? selection.start : text.length) + emoji.length,
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          );
        },
      ),
    );
  }
}
