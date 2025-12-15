class FAQData {
  static final List<Map<String, String>> faqs = [
    {
      'question': 'How does clock in/out work?',
      'answer': 'Go to Dashboard → My Shift → Clock In button. Make sure to clock out when you finish your shift.',
    },
    {
      'question': 'How to submit an injury report?',
      'answer': 'Open Reports → Injury → Submit new report. Your supervisor will review it.',
    },
    {
      'question': 'Call in Sick',
      'answer': '',
      'action': 'leave',
    },
    {
      'question': 'Client booking ended early',
      'answer': '',
      'action': 'client_issue',
    },
    {
      'question': 'Client not home',
      'answer': '',
      'action': 'client_issue',
    },
    {
      'question': 'Client cancelled',
      'answer': '',
      'action': 'client_issue',
    },
    {
      'question': 'Delay in arrival',
      'answer': '',
      'action': 'delay',
    },
    {
      'question': 'How to view my schedule?',
      'answer': 'Go to Dashboard → Shifts to see all your scheduled shifts, completed, and in-progress shifts.',
    },
    {
      'question': 'What should I do in an emergency?',
      'answer': 'Use the SOS button at the bottom of your dashboard to dial emergency services (911).',
    },
    {
      'question': 'How to update my profile?',
      'answer': 'Go to Dashboard → Employee Info → Click Edit to update your personal information.',
    },
  ];

  static Map<String, String>? findAnswer(String query) {
    final lowerQuery = query.toLowerCase();
    for (var faq in faqs) {
      if (faq['question']!.toLowerCase().contains(lowerQuery) ||
          lowerQuery.contains(faq['question']!.toLowerCase())) {
        return faq;
      }
    }
    return null;
  }

  static List<String> getFAQQuestions() {
    return faqs.map((faq) => faq['question']!).toList();
  }
}

