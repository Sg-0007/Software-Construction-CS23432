import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/document_vault.dart';
import '../services/supabase_service.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({Key? key}) : super(key: key);

  @override
  _VaultScreenState createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final ImagePicker _picker = ImagePicker();
  List<DocumentVault> _documents = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final docs = await SupabaseService.fetchDocuments();
      setState(() => _documents = docs);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading documents: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadNewDocument() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      await SupabaseService.uploadDocument(image, 'Uploaded Document: ${image.name}');
      await _loadDocuments();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document securely vaulted!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed. Ensure document bucket exists: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Document Vault', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading 
        ? Center(child: SpinKitThreeBounce(color: Theme.of(context).primaryColor, size: 20))
        : _documents.isEmpty 
          ? Center(child: Text('No documents securely vaulted yet.', style: GoogleFonts.inter()))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _documents.length,
              itemBuilder: (context, index) {
                final doc = _documents[index];
                final previewText = doc.extractedData?['status'] 
                    ?? doc.extractedData?['raw_text']?.toString().split('\n').first 
                    ?? 'OCR Data Missing';
                    
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.verified_user, color: Colors.indigo),
                    title: Text(doc.title, style: GoogleFonts.inter(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('OCR: $previewText', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.cloud_done, color: Colors.green, size: 20),
                  ),
                );
              },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _uploadNewDocument,
        icon: _isUploading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
          : const Icon(Icons.add_a_photo),
        label: Text(_isUploading ? 'Uploading...' : 'Upload Doc'),
      ),
    );
  }
}
