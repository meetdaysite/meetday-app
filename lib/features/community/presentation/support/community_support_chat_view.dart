import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';
import '../../../auth/domain/account_role.dart';
import '../../../auth/state/auth_provider.dart';
import '../chat/chat_formatting_utils.dart';
import '../providers/dashboard_provider.dart';
import '../providers/support_chat_provider.dart';

/// Meetday Support Chat screen matching the web dashboard MeetdayChatPanel.
/// Provides direct concierge communication with the Meetday admin and bot team.
class CommunitySupportChatView extends ConsumerStatefulWidget {
  const CommunitySupportChatView({super.key, this.role});

  final AccountRole? role;

  @override
  ConsumerState<CommunitySupportChatView> createState() => _CommunitySupportChatViewState();
}

class _CommunitySupportChatViewState extends ConsumerState<CommunitySupportChatView>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  Timer? _pollTimer;
  Timer? _highlightTimer;

  bool _isSending = false;
  bool _showEmojiPicker = false;
  bool _showFormattingBar = false;
  String? _editingMessageId;
  SupportChatMessage? _replyingTo;
  String? _highlightedMessageId;
  int _prevMessageCount = 0;

  @override
  bool get wantKeepAlive => true;

  AccountRole get _effectiveRole =>
      widget.role ?? ref.read(authControllerProvider).role ?? AccountRole.community;

  String get _contextParam {
    final role = _effectiveRole;
    return role == AccountRole.brand
        ? 'BRAND'
        : (role == AccountRole.space ? 'SPACE' : 'HOST');
  }

  void _invalidateMessages() {
    ref.invalidate(supportChatMessagesProvider(widget.role));
  }

  @override
  void initState() {
    super.initState();
    _markSupportRead();
    _focusNode.addListener(_onFocusChange);
    // Poll support messages every 4 seconds, matching POLL_MS on the website
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _invalidateMessages();
      }
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _scrollToBottom(smooth: true);
      });
    }
  }

  void _markSupportRead() {
    try {
      final api = ref.read(apiClientProvider);
      unawaited(
        api.dio.patch<dynamic>(
          '/notifications/read-by-thread',
          data: {'threadId': 'support'},
        ).then((_) {
          ref.invalidate(unreadNotificationsCountProvider);
        }).catchError((_) {}),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
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
        _invalidateMessages();
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

    try {
      final res = await sendSupportChatMessageApi(
        api,
        content: text,
        replyToId: replyId,
        context: _contextParam,
      );

      _textController.clear();
      setState(() {
        _replyingTo = null;
      });

      _invalidateMessages();
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
      _invalidateMessages();
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

  Future<void> _pickAndSendDeviceFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'doc', 'docx', 'txt'],
      );
      if (result.isEmpty) return;
      final file = result.first;
      final bytes = await file.xFile.readAsBytes();
      if (bytes.isEmpty) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading attachment...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.black87,
          ),
        );
      }

      setState(() => _isSending = true);
      final api = ref.read(apiClientProvider);
      final key = await api.uploadMediaFile(
        bytes: bytes,
        fileName: file.name,
        context: 'SUPPORT_CHAT_MEDIA',
      );

      if (key != null && key.isNotEmpty) {
        await sendSupportChatMessageApi(
          api,
          content: file.name,
          mediaKey: key,
          replyToId: _replyingTo?.id,
          context: _contextParam,
        );
        setState(() => _replyingTo = null);
        _invalidateMessages();
        _scrollToBottom();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload failed. Please try again.'),
              backgroundColor: MeetdayColors.primaryRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick file: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading image...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.black87,
          ),
        );
      }

      setState(() => _isSending = true);
      final api = ref.read(apiClientProvider);
      final key = await api.uploadMediaFile(
        bytes: bytes,
        fileName: picked.name,
        context: 'SUPPORT_CHAT_MEDIA',
      );

      if (key != null && key.isNotEmpty) {
        await sendSupportChatMessageApi(
          api,
          content: '',
          mediaKey: key,
          replyToId: _replyingTo?.id,
          context: _contextParam,
        );
        setState(() => _replyingTo = null);
        _invalidateMessages();
        _scrollToBottom();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload failed. Please try again.'),
              backgroundColor: MeetdayColors.primaryRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
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
              'Attach File or Media',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a file from your device or paste a media link.',
              style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            // Options Row: Device File & Gallery & Camera
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendDeviceFile();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: MeetdayColors.accentYellow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_open_rounded, size: 24, color: Colors.black),
                          const SizedBox(height: 6),
                          Text(
                            'Choose File',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage(ImageSource.gallery);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded, size: 24, color: Colors.black),
                          const SizedBox(height: 6),
                          Text(
                            'Gallery',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage(ImageSource.camera);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_rounded, size: 24, color: Colors.black),
                          const SizedBox(height: 6),
                          Text(
                            'Camera',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider(thickness: 1.5, color: Colors.black26)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('OR PASTE URL', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black45)),
                ),
                const Expanded(child: Divider(thickness: 1.5, color: Colors.black26)),
              ],
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
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),
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
                  try {
                    final api = ref.read(apiClientProvider);
                    await sendSupportChatMessageApi(
                      api,
                      content: '',
                      mediaUrl: url,
                      replyToId: _replyingTo?.id,
                      context: _contextParam,
                    );
                    setState(() => _replyingTo = null);
                    _invalidateMessages();
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
                  'Send Link Attachment',
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
    super.build(context);
    final messagesAsync = ref.watch(supportChatMessagesProvider(widget.role));

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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17.5),
                child: Column(
                  children: [
                    // Inner Panel Header: "Talk to Meetday"
                    _buildPanelHeader(),

                  // Message List
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (messagesAsync.isLoading && !messagesAsync.hasValue) {
                          return const Center(
                            child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
                          );
                        }

                        if (messagesAsync.hasError && !messagesAsync.hasValue) {
                          return Center(
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
                                  onPressed: _invalidateMessages,
                                  child: Text('Retry', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          );
                        }

                        final messages = messagesAsync.value ?? const <SupportChatMessage>[];

                        if (messages.length > _prevMessageCount) {
                          final isInitial = _prevMessageCount == 0;
                          _prevMessageCount = messages.length;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted || !_scrollController.hasClients) return;
                            final isNearBottom = _scrollController.position.extentAfter < 120;
                            if (isInitial || isNearBottom) {
                              _scrollToBottom(smooth: !isInitial);
                            }
                          });
                        } else if (messages.length != _prevMessageCount) {
                          _prevMessageCount = messages.length;
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
                            final curDt = (m.createdAt ?? DateTime.now()).toLocal();
                            bool showDateHeader = false;
                            if (index == 0) {
                              showDateHeader = true;
                            } else {
                              final prevDt = (messages[index - 1].createdAt ?? DateTime.now()).toLocal();
                              if (curDt.year != prevDt.year || curDt.month != prevDt.month || curDt.day != prevDt.day) {
                                showDateHeader = true;
                              }
                            }

                            if (showDateHeader) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildDateBadge(_getDateBadgeText(curDt)),
                                  _buildMessageItem(m, messages),
                                ],
                              );
                            }
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

                  // Formatting Toolbar
                  if (_showFormattingBar)
                    ChatFormattingToolbar(
                      onApplyFormat: (prefix, suffix) {
                        applyChatFormatting(_textController, prefix, suffix);
                        setState(() {});
                      },
                      onClose: () => setState(() => _showFormattingBar = false),
                    ),

                  // Bottom Composer
                  _buildComposer(),

                  // Emoji picker drawer
                  if (_showEmojiPicker) _buildEmojiPicker(),
                ],
              ),
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
            onTap: _invalidateMessages,
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

  String _formatOrdinalDay(DateTime dt) {
    final day = dt.day;
    String suffix = 'th';
    if (day >= 11 && day <= 13) {
      suffix = 'th';
    } else {
      switch (day % 10) {
        case 1:
          suffix = 'st';
          break;
        case 2:
          suffix = 'nd';
          break;
        case 3:
          suffix = 'rd';
          break;
        default:
          suffix = 'th';
      }
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '$day$suffix ${months[dt.month - 1]} ${dt.year}';
  }

  String _getDateBadgeText(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(dt.year, dt.month, dt.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return _formatOrdinalDay(dt);
    }
  }

  Widget _buildDateBadge(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black26, width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF4B5563),
          ),
        ),
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

    if (m.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'This message was deleted',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: Colors.black45,
              ),
            ),
          ),
        ),
      );
    }

    final timeString = m.createdAt != null
        ? DateFormat('hh:mm a').format(m.createdAt!)
        : '';

    final isSpace = ref.watch(authControllerProvider).role == AccountRole.space;
    final isRedBubble = isMine && isBrand;
    final isBlackBubble = isMine && isSpace;
    final bubbleColor = isMine
        ? (isSpace
            ? Colors.black
            : (isBrand ? MeetdayColors.primaryRed : MeetdayColors.accentYellow))
        : const Color(0xFFF3F4F6);
    final contentTextColor =
        (isRedBubble || isBlackBubble) ? Colors.white : const Color(0xFF111111);

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
          // Header Label
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
            child: Text(
              senderLabel,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Colors.black45,
              ),
            ),
          ),

          // Message Bubble
          GestureDetector(
            onLongPress: () => _showMessageContextMenu(m, allMessages),
            child: ConstrainedBox(
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

                  // Media attachment if any
                  if (m.mediaUrl != null && m.mediaUrl!.isNotEmpty) ...[
                    Builder(
                      builder: (ctx) {
                        final urlLower = m.mediaUrl!.toLowerCase();
                        final isDoc = urlLower.contains('.pdf') ||
                            urlLower.contains('.doc') ||
                            urlLower.contains('.docx') ||
                            urlLower.contains('.txt');
                        if (isDoc) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black, width: 1.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.description_rounded, size: 20, color: MeetdayColors.primaryRed),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    m.content.isNotEmpty ? m.content : 'Attached Document',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Padding(
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
                        );
                      },
                    ),
                  ],

                  // Message content text
                  if (m.content.isNotEmpty)
                    RichText(
                      text: TextSpan(
                        children: parseChatFormattedText(
                          m.content,
                          baseStyle: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: contentTextColor,
                            height: 1.35,
                          ),
                          isDarkBubble: isRedBubble,
                        ),
                      ),
                    ),
                ],
              ),
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

          // Formatting toggle button
          GestureDetector(
            onTap: () => setState(() => _showFormattingBar = !_showFormattingBar),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _showFormattingBar ? MeetdayColors.accentYellow : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                ],
              ),
              child: const Center(
                child: Icon(Icons.format_size_rounded, size: 18, color: Colors.black87),
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
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  filled: false,
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

  // ─── Context Menu Bottom Sheet ─────────────────────────────────────────────

  void _showMessageContextMenu(
    SupportChatMessage msg,
    List<SupportChatMessage> allMessages,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Colors.black, width: 2.5),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Formatting shortcuts on long press
              buildChatFormattingActionRow(
                onFormat: (prefix, suffix) {
                  Navigator.of(ctx).pop();
                  applyChatFormatting(_textController, prefix, suffix);
                  setState(() => _showFormattingBar = true);
                  _focusNode.requestFocus();
                },
              ),
              const Divider(color: Colors.black12, thickness: 1, indent: 16, endIndent: 16),
              if (!msg.isDeleted)
                ListTile(
                  leading: const Icon(Icons.reply_rounded, color: Colors.black),
                  title: Text(
                    'Reply',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _editingMessageId = null;
                      _replyingTo = msg;
                    });
                    _focusNode.requestFocus();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.black),
                title: Text(
                  'Copy Text',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Clipboard.setData(ClipboardData(text: msg.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied to clipboard'),
                    ),
                  );
                },
              ),
              if (msg.isMine && !msg.isDeleted) ...[
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Colors.black),
                  title: Text(
                    'Edit Message',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _handleStartEdit(msg);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: MeetdayColors.primaryRed,
                  ),
                  title: Text(
                    'Delete Message',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: MeetdayColors.primaryRed,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _handleDelete(msg);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
