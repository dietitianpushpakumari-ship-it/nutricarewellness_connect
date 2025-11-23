import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nutricare_connect/features/dietplan/domain/entities/package_model.dart';

class PackageBrowserScreen extends StatelessWidget {
  const PackageBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Explore Plans")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('packages').where('isActive', isEqualTo: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final pkg = PackageModel.fromFirestore(snapshot.data!.docs[index]);
              return Card(
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(pkg.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(pkg.description),
                      const SizedBox(height: 8),
                      Text("${pkg.durationDays} Days  •  ₹${pkg.price}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // Navigate to Chat with pre-filled text "I'm interested in [Package Name]"
                    },
                    child: const Text("Enquire"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}