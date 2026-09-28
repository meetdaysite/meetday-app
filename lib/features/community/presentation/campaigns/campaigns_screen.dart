import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  String selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final campaigns = [
      {
        'brand': 'Nike',
        'title': 'Summer Sports Campaign',
        'budget': '₹50L',
        'deadline': '30 Oct',
        'status': 'Open',
        'category': 'Sports',
      },
      {
        'brand': 'Coca-Cola',
        'title': 'Youth Festival Sponsorship',
        'budget': '₹75L',
        'deadline': '25 Oct',
        'status': 'Open',
        'category': 'Beverage',
      },
      {
        'brand': 'Apple',
        'title': 'Tech Launch Event',
        'budget': '₹1Cr',
        'deadline': '20 Oct',
        'status': 'Applied',
        'category': 'Technology',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Brand Campaigns',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Explore opportunities to partner with brands',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list),
              label: const Text('Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEE2C2C),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Category filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: selectedCategory == 'All',
                onTap: () => setState(() => selectedCategory = 'All'),
              ),
              _FilterChip(
                label: 'Technology',
                selected: selectedCategory == 'Technology',
                onTap: () => setState(() => selectedCategory = 'Technology'),
              ),
              _FilterChip(
                label: 'Beverage',
                selected: selectedCategory == 'Beverage',
                onTap: () => setState(() => selectedCategory = 'Beverage'),
              ),
              _FilterChip(
                label: 'Sports',
                selected: selectedCategory == 'Sports',
                onTap: () => setState(() => selectedCategory = 'Sports'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Stats
        Row(
          children: [
            Expanded(
              child: _StatTile(label: 'Active', value: '${campaigns.length}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(label: 'Applied', value: '2'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(label: 'Closed', value: '5'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Campaigns list
        ...campaigns.map((campaign) => _CampaignCard(campaign: campaign)).toList(),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEE2C2C) : Colors.white,
            border: Border.all(
              color: selected ? const Color(0xFFEE2C2C) : const Color(0xFFE5E7EB),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF667085),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFFEE2C2C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});

  final Map<String, dynamic> campaign;

  @override
  Widget build(BuildContext context) {
    final isApplied = campaign['status'] == 'Applied';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign['brand'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      campaign['title'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isApplied ? const Color(0xFFDCFCE7) : const Color(0xFFFFF2C8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  campaign['status'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isApplied ? const Color(0xFF12B76A) : const Color(0xFFF0A12B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 14, color: Color(0xFF667085)),
                  const SizedBox(width: 4),
                  Text(
                    campaign['budget'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFF667085)),
                  const SizedBox(width: 4),
                  Text(
                    campaign['deadline'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: isApplied ? const Color(0xFFE5E7EB) : const Color(0xFFEE2C2C),
                  foregroundColor: isApplied ? const Color(0xFF667085) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text(isApplied ? 'Applied' : 'Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
