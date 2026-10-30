import 'package:app_common_kit/app_common_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 報告に付ける、アプリの名前と版。Firestore の `feedback` で、どのアプリの報告かを見分ける。
const kFeedbackAppName = 'seisei_ai_passport';
const kFeedbackAppVersion = '1.0.4';

/// 報告を Firestore の `feedback` に書き込む。
/// ルール(firestore.rules)は「サインイン済みで、userId が自分の uid」を要求するため、
/// 匿名でサインインしてから、userId を自分の uid に揃えて書く。
/// 失敗(オフライン等)は、キット側が端末に残して、次の機会に再送する。
Future<void> submitFeedbackReport(FeedbackReport report) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
  if (user == null) throw StateError('anonymous sign-in failed');
  final data = report.toJson()..['userId'] = user.uid;
  await FirebaseFirestore.instance.collection('feedback').doc(report.id).set(data);
}

/// 設定画面の「ご意見・不具合報告」。押すと、送信先を登録して、フォームを開く。
class FeedbackTile extends ConsumerWidget {
  const FeedbackTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.feedback_outlined),
      title: const Text('ご意見・不具合報告'),
      subtitle: const Text('バグ報告や改善要望をお寄せください'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        final notifier = ref.read(feedbackProvider.notifier);
        notifier.setSubmitHandler(submitFeedbackReport);
        // 前に送れなかった分があれば、いまもう一度送る。
        notifier.retryPendingReports();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const FeedbackFormPage(
              appName: kFeedbackAppName,
              appVersion: kFeedbackAppVersion,
            ),
          ),
        );
      },
    );
  }
}
