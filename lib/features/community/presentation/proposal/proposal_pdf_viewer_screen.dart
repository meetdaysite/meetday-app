import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';

class ProposalPdfViewerScreen extends StatefulWidget {
  final String? proposalId;
  final String pdfUrl;
  final String title;

  const ProposalPdfViewerScreen({
    super.key,
    this.proposalId,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<ProposalPdfViewerScreen> createState() => _ProposalPdfViewerScreenState();
}

class _ProposalPdfViewerScreenState extends State<ProposalPdfViewerScreen> {
  late final PdfViewerController _pdfViewerController;
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  String _loadingMessage = 'Loading Proposal PDF...';
  double? _downloadProgress;
  String? _errorMessage;
  int _pageCount = 0;
  int _currentPage = 1;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _currentUrl = widget.pdfUrl;
    _loadPdf();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  bool _isValidPdf(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // PDF magic bytes signature: %PDF (0x25, 0x50, 0x44, 0x46)
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  Future<String?> _fetchFreshDocUrl(String proposalId) async {
    final dio = ApiClient.instance.dio;

    // 1. Try host/space proposal detail endpoint
    try {
      final res = await dio.get<dynamic>('/sponsorships/$proposalId');
      if (res.statusCode == 200 && res.data != null) {
        final body = res.data;
        final map = (body is Map && body.containsKey('data')) ? body['data'] : body;
        if (map is Map && map['docUrl'] != null && map['docUrl'].toString().isNotEmpty) {
          return map['docUrl'].toString();
        }
      }
    } catch (e) {
      debugPrint('Could not fetch fresh docUrl from /sponsorships/$proposalId: $e');
    }

    // 2. Fallback to public explore endpoint (e.g. for brand view or public preview)
    try {
      final res = await dio.get<dynamic>('/sponsorships/explore/$proposalId');
      if (res.statusCode == 200 && res.data != null) {
        final body = res.data;
        final map = (body is Map && body.containsKey('data')) ? body['data'] : body;
        if (map is Map && map['docUrl'] != null && map['docUrl'].toString().isNotEmpty) {
          return map['docUrl'].toString();
        }
      }
    } catch (e) {
      debugPrint('Could not fetch fresh docUrl from /sponsorships/explore/$proposalId: $e');
    }

    return null;
  }

  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(seconds: 45),
          followRedirects: true,
        ),
      );

      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'application/pdf,application/octet-stream,*/*',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              _downloadProgress = received / total;
              final percent = (_downloadProgress! * 100).toInt();
              _loadingMessage = 'Downloading PDF ($percent%)...';
            });
          }
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      }
    } catch (e) {
      debugPrint('Error downloading PDF bytes: $e');
    }
    return null;
  }

  Future<void> _loadPdf({bool forceRefreshUrl = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _downloadProgress = null;
      _loadingMessage = forceRefreshUrl
          ? 'Refreshing document access...'
          : 'Loading Proposal PDF...';
    });

    try {
      String? urlToUse = _currentUrl;

      // If forcing refresh or URL is empty, fetch fresh presigned URL from backend
      if (forceRefreshUrl || urlToUse == null || urlToUse.trim().isEmpty) {
        if (widget.proposalId != null && widget.proposalId!.isNotEmpty) {
          if (mounted) {
            setState(() => _loadingMessage = 'Fetching fresh access token...');
          }
          final freshUrl = await _fetchFreshDocUrl(widget.proposalId!);
          if (freshUrl != null && freshUrl.isNotEmpty) {
            urlToUse = freshUrl;
            _currentUrl = freshUrl;
          }
        }
      }

      if (urlToUse == null || urlToUse.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No PDF document attached to this proposal.';
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _loadingMessage = 'Downloading proposal deck...');
      }

      Uint8List? bytes = await _downloadBytes(urlToUse);

      // If initial download returned non-PDF (e.g. XML AccessDenied because presigned URL expired),
      // and we haven't already refreshed, fetch a fresh URL and retry!
      if ((bytes == null || !_isValidPdf(bytes)) &&
          !forceRefreshUrl &&
          widget.proposalId != null &&
          widget.proposalId!.isNotEmpty) {
        if (mounted) {
          setState(() => _loadingMessage = 'Link expired. Refreshing secure token...');
        }
        final freshUrl = await _fetchFreshDocUrl(widget.proposalId!);
        if (freshUrl != null && freshUrl.isNotEmpty && freshUrl != urlToUse) {
          _currentUrl = freshUrl;
          bytes = await _downloadBytes(freshUrl);
        }
      }

      if (bytes != null && _isValidPdf(bytes)) {
        if (mounted) {
          setState(() {
            _pdfBytes = bytes;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Could not load PDF document. The link may have expired or is unavailable.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Network error while loading PDF. Tap Retry to reconnect.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValidTarget = (_currentUrl != null && _currentUrl!.trim().isNotEmpty) ||
        (widget.proposalId != null && widget.proposalId!.isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF8F3),
              border: Border(
                bottom: BorderSide(color: Colors.black, width: 2.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black,
                  offset: Offset(0, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                // Back Button (Tactile neo-brutalist)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Back',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Document Title & Page Count
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title.isNotEmpty ? widget.title : 'Proposal Pitch Deck',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      if (_pageCount > 0)
                        Text(
                          'Page $_currentPage of $_pageCount',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF525252),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // PDF Badge Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: MeetdayColors.primaryRed,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(1.5, 1.5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    'PDF',
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: !hasValidTarget
          ? _buildInvalidUrlState()
          : _isLoading
              ? _buildLoadingState()
              : _errorMessage != null
                  ? _buildErrorState()
                  : _pdfBytes == null
                      ? _buildInvalidUrlState()
                      : SfPdfViewer.memory(
                          _pdfBytes!,
                          controller: _pdfViewerController,
                          canShowScrollHead: true,
                          canShowScrollStatus: true,
                          canShowPaginationDialog: true,
                          enableDoubleTapZooming: true,
                          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                            if (mounted) {
                              setState(() {
                                _pageCount = details.document.pages.count;
                              });
                            }
                          },
                          onPageChanged: (PdfPageChangedDetails details) {
                            if (mounted) {
                              setState(() {
                                _currentPage = details.newPageNumber;
                              });
                            }
                          },
                          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                            if (mounted) {
                              setState(() {
                                _errorMessage = details.description.isNotEmpty
                                    ? details.description
                                    : 'Failed to render PDF document.';
                              });
                            }
                          },
                        ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: const Color(0xFFFFFDFC),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(3, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  color: MeetdayColors.primaryRed,
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _loadingMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              if (_downloadProgress != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 8,
                    width: 180,
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: const Color(0xFFF3F4F6),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        MeetdayColors.accentYellow,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvalidUrlState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 28,
                  color: MeetdayColors.primaryRed,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No PDF Attached',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This proposal does not have a valid PDF document attached yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF525252),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: MeetdayColors.primaryRed,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 28,
                  color: MeetdayColors.primaryRed,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Could Not Load PDF',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage ?? 'Network error occurred while fetching the proposal deck.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF525252),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _loadPdf(forceRefreshUrl: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: MeetdayColors.accentYellow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(
                        'Go Back',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
