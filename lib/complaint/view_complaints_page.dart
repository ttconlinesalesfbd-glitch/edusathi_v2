import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edusathi_v2/auth_helper.dart';
import 'package:edusathi_v2/complaint/addComplaint.dart';
import 'package:edusathi_v2/complaint/complaint_detail_page.dart';
import 'package:edusathi_v2/dashboard/dashboard_screen.dart';

class ViewComplaintPage extends StatefulWidget {
  const ViewComplaintPage({super.key});

  @override
  State<ViewComplaintPage> createState() => _ViewComplaintPageState();
}

class _ViewComplaintPageState extends State<ViewComplaintPage> {
  final String apiUrl = 'https://schoolerp.edusathi.in/api/student/complaint';

  List<dynamic> complaints = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchComplaints();
  }

  // ====================================================
  // 🔐 SAFE FETCH COMPLAINTS (iOS + ANDROID)
  // ====================================================
  Future<void> fetchComplaints() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final res = await AuthHelper.post(context, apiUrl);

      // AuthHelper handles 401 + logout
      if (res == null) return;

      debugPrint("📥 COMPLAINT LIST STATUS: ${res.statusCode}");
      debugPrint("📥 COMPLAINT LIST BODY: ${res.body}");

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        if (!mounted) return;
        setState(() {
          complaints = decoded is List ? decoded : [];
        });
      } else {
        if (!mounted) return;
        complaints = [];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load complaints')),
        );
      }
    } catch (e) {
      debugPrint("🚨 COMPLAINT LIST ERROR: $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Color getStatusColor(int status) {
    return status == 1 ? Colors.green : Colors.orange;
  }

  String getStatusText(int status) {
    return status == 1 ? 'Solved' : 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Complaints',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          },
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : complaints.isEmpty
              ? const Center(child: Text('No complaints available'))
              : ListView.builder(
                  itemCount: complaints.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final complaint = complaints[index];
                    final status = complaint['Status'];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComplaintDetailPage(
                              complaintId: complaint['id'],
                              date: complaint['Date'],
                              description: complaint['Description'],
                              status: status,
                            ),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.date_range,
                                    color: Colors.deepPurple,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatDate(complaint['Date'] ?? ''),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(status)
                                          .withOpacity(0.1),
                                      border: Border.all(
                                        color: getStatusColor(status),
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      getStatusText(status),
                                      style: TextStyle(
                                        color: getStatusColor(status),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                complaint['Description']
                                        ?.replaceAll(r"\r\n", "\n") ??
                                    '',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddComplaint()),
          ).then((_) {
            fetchComplaints(); // refresh after add
          });
        },
      ),
    );
  }
}

// ====================================================
// 📅 DATE FORMATTER (SAFE)
// ====================================================
String formatDate(String dateStr) {
  try {
    final date = DateTime.parse(dateStr);
    return DateFormat('dd-MM-yyyy').format(date);
  } catch (_) {
    return dateStr;
  }
}
