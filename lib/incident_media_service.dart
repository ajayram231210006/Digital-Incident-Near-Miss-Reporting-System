import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';

class IncidentMediaService {
  const IncidentMediaService();

  Future<String?> uploadImage(File file) async {
    final cloudinary = CloudinaryPublic(
      'djosnccv7',
      'incident_image',
      cache: false,
    );

    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Image,
      ),
    );

    return response.secureUrl;
  }

  Future<String?> uploadVideo(File file) async {
    final cloudinary = CloudinaryPublic(
      'djosnccv7',
      'incident_image',
      cache: false,
    );

    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Video,
        folder: 'incident_videos',
      ),
    );

    return response.secureUrl;
  }
}
