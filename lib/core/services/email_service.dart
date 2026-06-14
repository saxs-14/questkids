import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class EmailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send email through Firebase Cloud Functions with SMTP
  /// This method triggers a Cloud Function that handles SMTP delivery
  Future<void> sendEmail({
    required String recipientEmail,
    required String subject,
    required String templateName,
    required Map<String, dynamic> templateData,
  }) async {
    try {
      // Write to emails collection - Cloud Function will listen and process
      await _firestore.collection('emails').add({
        'to': recipientEmail,
        'subject': subject,
        'templateName': templateName,
        'templateData': templateData,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      throw Exception('Failed to send email: $e');
    }
  }

  /// Send welcome email to new user
  Future<void> sendWelcomeEmail({
    required String email,
    required String displayName,
  }) async {
    await sendEmail(
      recipientEmail: email,
      subject: 'Welcome to QuestKids 2.0! 🎮',
      templateName: 'welcome',
      templateData: {
        'displayName': displayName,
        'appName': 'QuestKids',
        'grade': 4,
      },
    );
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail({
    required String email,
    required String resetLink,
  }) async {
    await sendEmail(
      recipientEmail: email,
      subject: 'Reset Your QuestKids Password',
      templateName: 'password-reset',
      templateData: {
        'resetLink': resetLink,
        'expiryTime': '1 hour',
      },
    );
  }

  /// Send achievement email
  Future<void> sendAchievementEmail({
    required String email,
    required String displayName,
    required String achievement,
    required int points,
  }) async {
    await sendEmail(
      recipientEmail: email,
      subject: '🏆 $displayName earned a new achievement!',
      templateName: 'achievement',
      templateData: {
        'displayName': displayName,
        'achievement': achievement,
        'points': points,
      },
    );
  }

  /// Send email verification
  Future<void> sendVerificationEmail({
    required String email,
    required String verificationLink,
  }) async {
    await sendEmail(
      recipientEmail: email,
      subject: 'Verify Your QuestKids Email Address',
      templateName: 'email-verification',
      templateData: {
        'verificationLink': verificationLink,
        'expiryTime': '24 hours',
      },
    );
  }

  /// Check email send status
  Future<String?> getEmailStatus(String docId) async {
    try {
      final doc = await _firestore.collection('emails').doc(docId).get();
      return doc.data()?['status'] as String?;
    } catch (e) {
      debugPrint('Error checking email status: $e');
      return null;
    }
  }
}

/// Email configuration constants
class EmailConfig {
  /// SMTP Server Configuration (update these with your values)
  static const String senderAddress = 'support@questkids.com';
  static const String smtpServerHost = 'smtp.gmail.com'; // for Gmail
  static const int smtpServerPort = 587; // TLS port
  static const String smtpUsername = 'questkids.dev@gmail.com';
  // Password should be stored in Firebase Function environment variables
  static const String smtpSecurityMode = 'tls'; // or 'ssl'

  /// Email templates
  static const Map<String, String> emailTemplates = {
    'welcome': 'Welcome to QuestKids!',
    'password-reset': 'Reset Your Password',
    'achievement': 'New Achievement Unlocked!',
    'email-verification': 'Verify Your Email',
    'daily-challenge': 'Daily Challenge Available',
    'level-up': 'Level Up!',
  };
}
