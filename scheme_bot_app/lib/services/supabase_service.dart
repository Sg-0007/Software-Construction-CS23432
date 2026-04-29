import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/document_vault.dart';

class SupabaseService {
  static final _supabase = Supabase.instance.client;

  static Future<List<DocumentVault>> fetchDocuments() async {
    final response = await _supabase
        .from('document_vault')
        .select()
        .eq('user_id', _supabase.auth.currentUser!.id)
        .order('uploaded_at', ascending: false);
    
    return (response as List).map((e) => DocumentVault.fromJson(e)).toList();
  }

  static Future<void> uploadDocument(XFile file, String title) async {
    final userId = _supabase.auth.currentUser!.id;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    
    // 1. Storage Upload (Cross-platform binary pipeline)
    final bytes = await file.readAsBytes();
    await _supabase.storage.from('documents').uploadBinary(
      fileName,
      bytes,
      fileOptions: FileOptions(contentType: 'image/jpeg'),
    );

    final String publicUrl = _supabase.storage.from('documents').getPublicUrl(fileName);

    // 2. OCR Extraction (Web Safe Fallback)
    Map<String, dynamic> extractedData = {};
    if (kIsWeb) {
      extractedData = {"status": "OCR skipped on web"};
    } else {
      try {
        final inputImage = InputImage.fromFilePath(file.path);
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        extractedData = {"raw_text": recognizedText.text};
        await textRecognizer.close();
      } catch (e) {
        extractedData = {"error": "OCR processing failed natively: $e"};
      }
    }

    // 3. Database Insert
    await _supabase.from('document_vault').insert({
      'user_id': userId,
      'title': title,
      'document_url': publicUrl,
      'extracted_data': extractedData,
    });
  }
}
