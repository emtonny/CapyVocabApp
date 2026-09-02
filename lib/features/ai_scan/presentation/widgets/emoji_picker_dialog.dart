import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class EmojiItem {
  const EmojiItem({
    required this.emoji,
    required this.name,
    required this.category,
    required this.keywords,
  });

  final String emoji;
  final String name;
  final String category;
  final String keywords;
}

class EmojiPickerDialog extends StatefulWidget {
  const EmojiPickerDialog({
    super.key,
    required this.title,
    required this.currentEmoji,
    this.controlKey = 'emoji-picker',
  });

  final String title;
  final String currentEmoji;
  final String controlKey;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String currentEmoji,
    String controlKey = 'emoji-picker',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => EmojiPickerDialog(
        title: title,
        currentEmoji: currentEmoji,
        controlKey: controlKey,
      ),
    );
  }

  @override
  State<EmojiPickerDialog> createState() => _EmojiPickerDialogState();
}

class _EmojiPickerDialogState extends State<EmojiPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Gợi ý';
  String _searchQuery = '';

  static const _studioGreenDark = AppColors.darkGreen;
  static const _ink = AppColors.ink;
  static const _mutedInk = AppColors.mutedInk;

  final List<String> _categories = const [
    'Gợi ý',
    'Mặt cười',
    'Động vật',
    'Đồ ăn',
    'Học tập',
    'Quốc kỳ',
    'Biểu tượng',
    'Hoạt động',
    'Du lịch',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String input) {
    var result = input.toLowerCase();
    const withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const withoutDia =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (var i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }

  List<EmojiItem> _getFilteredEmojis() {
    if (_searchQuery.isNotEmpty) {
      final normalizedQuery = _normalize(_searchQuery);
      final seen = <String>{};
      final results = <EmojiItem>[];
      for (final item in _allEmojis) {
        if (seen.contains(item.emoji)) continue;
        final normName = _normalize(item.name);
        final normKeywords = _normalize(item.keywords);
        if (normName.contains(normalizedQuery) ||
            normKeywords.contains(normalizedQuery) ||
            item.emoji == _searchQuery) {
          seen.add(item.emoji);
          results.add(item);
        }
      }
      return results;
    }

    if (_selectedCategory == 'Gợi ý') {
      return _allEmojis.where((item) => item.category == 'Gợi ý').toList();
    }

    return _allEmojis
        .where((item) => item.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredEmojis();

    return AlertDialog(
      backgroundColor: AppColors.softWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.ink, width: 2.8),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.ink, width: 1.8),
            ),
            child: const Icon(
              Icons.sentiment_satisfied_alt_rounded,
              color: AppColors.ink,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const Text(
                  'Kho biểu tượng sắc màu chuẩn iPhone',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11.5,
                    color: _mutedInk,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22, color: _ink),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.yellow,
              minimumSize: const Size.square(48),
              side: const BorderSide(color: AppColors.ink, width: 1.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ô tìm kiếm iPhone
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: _mutedInk,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded,
                              size: 18, color: _mutedInk),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  hintText: 'Tìm kiếm: mèo, cờ vn, sách, tim, bơ, sao...',
                  hintStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12.5,
                    color: AppColors.mutedInk,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Thanh danh mục
            if (_searchQuery.isEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Nút tắt icon nhanh
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar: const Icon(Icons.block_rounded,
                            size: 14, color: Color(0xFFC2410C)),
                        label: const Text('Không dùng'),
                        backgroundColor: const Color(0xFFFFE3DB),
                        side: const BorderSide(
                          color: AppColors.ink,
                          width: 1.8,
                        ),
                        labelStyle: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC2410C),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onPressed: () => Navigator.of(context).pop(''),
                      ),
                    ),
                    for (final category in _categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          selectedColor: AppColors.lime,
                          backgroundColor: Colors.white,
                          checkmarkColor: _studioGreenDark,
                          labelStyle: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11.5,
                            fontWeight: _selectedCategory == category
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: _selectedCategory == category
                                ? _studioGreenDark
                                : _ink,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: AppColors.ink,
                              width: _selectedCategory == category ? 2 : 1.5,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = category);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),

            // Lưới icon Emoji
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: filteredList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔍', style: TextStyle(fontSize: 32)),
                            const SizedBox(height: 8),
                            Text(
                              'Không tìm thấy icon nào cho "$_searchQuery"',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 13,
                                color: _mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => GridView.builder(
                        shrinkWrap: true,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth < 232
                              ? 3
                              : constraints.maxWidth < 340
                                  ? 4
                                  : 6,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          final isSelected = item.emoji == widget.currentEmoji;

                          return Tooltip(
                            message: item.name,
                            child: Material(
                              color: isSelected ? AppColors.mint : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: AppColors.ink,
                                  width: isSelected ? 2.4 : 1.5,
                                ),
                              ),
                              child: InkWell(
                                key: Key('${widget.controlKey}-$index'),
                                borderRadius: BorderRadius.circular(8),
                                onTap: () =>
                                    Navigator.of(context).pop(item.emoji),
                                child: Center(
                                  child: Text(
                                    item.emoji,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bảng dữ liệu kho Emoji đồ sộ phân loại theo chuẩn iPhone kèm từ khoá tìm kiếm Việt & Anh
final List<EmojiItem> _allEmojis = [
  // Gợi ý hay dùng cho nhãn từ vựng (Popular)
  const EmojiItem(emoji: '🦌', name: 'Hươu', category: 'Gợi ý', keywords: 'huou deer animal dong vat'),
  const EmojiItem(emoji: '🦫', name: 'Capybara', category: 'Gợi ý', keywords: 'capybara chuot lang animal dong vat'),
  const EmojiItem(emoji: '💖', name: 'Trái tim', category: 'Gợi ý', keywords: 'trai tim tim heart love'),
  const EmojiItem(emoji: '🍪', name: 'Bánh quy', category: 'Gợi ý', keywords: 'banh quy cookie biscuit sweet'),
  const EmojiItem(emoji: '📌', name: 'Ghim đỏ', category: 'Gợi ý', keywords: 'ghim do pin note note label'),
  const EmojiItem(emoji: '🐶', name: 'Cún con', category: 'Gợi ý', keywords: 'cho cun dog puppy animal'),
  const EmojiItem(emoji: '🐱', name: 'Mèo con', category: 'Gợi ý', keywords: 'meo cat kitty animal'),
  const EmojiItem(emoji: '🐰', name: 'Thỏ trắng', category: 'Gợi ý', keywords: 'tho rabbit bunny animal'),
  const EmojiItem(emoji: '🐻', name: 'Gấu nâu', category: 'Gợi ý', keywords: 'gau bear animal'),
  const EmojiItem(emoji: '🐼', name: 'Gấu trúc', category: 'Gợi ý', keywords: 'gau truc panda animal'),
  const EmojiItem(emoji: '🦊', name: 'Cáo đỏ', category: 'Gợi ý', keywords: 'cao fox animal'),
  const EmojiItem(emoji: '🐾', name: 'Dấu chân', category: 'Gợi ý', keywords: 'dau chan paw pet animal'),
  const EmojiItem(emoji: '🍓', name: 'Dâu tây', category: 'Gợi ý', keywords: 'dau tay strawberry fruit trai cay'),
  const EmojiItem(emoji: '🥑', name: 'Quả bơ', category: 'Gợi ý', keywords: 'qua bo avocado fruit'),
  const EmojiItem(emoji: '🍎', name: 'Táo đỏ', category: 'Gợi ý', keywords: 'tao apple fruit'),
  const EmojiItem(emoji: '🍕', name: 'Pizza', category: 'Gợi ý', keywords: 'pizza do an food'),
  const EmojiItem(emoji: '🧁', name: 'Cupcake', category: 'Gợi ý', keywords: 'cupcake banh kem cake sweet'),
  const EmojiItem(emoji: '☕', name: 'Cà phê', category: 'Gợi ý', keywords: 'ca phe coffee cafe drink'),
  const EmojiItem(emoji: '🧋', name: 'Trà sữa', category: 'Gợi ý', keywords: 'tra sua milk tea boba drink'),
  const EmojiItem(emoji: '⭐', name: 'Ngôi sao', category: 'Gợi ý', keywords: 'ngoi sao star symbol'),
  const EmojiItem(emoji: '🎀', name: 'Nơ hồng', category: 'Gợi ý', keywords: 'no ribbon bow cute'),
  const EmojiItem(emoji: '👑', name: 'Vương miện', category: 'Gợi ý', keywords: 'vuong mien crown king queen'),
  const EmojiItem(emoji: '🎈', name: 'Bóng bay', category: 'Gợi ý', keywords: 'bong bay balloon party'),
  const EmojiItem(emoji: '🧸', name: 'Gấu bông', category: 'Gợi ý', keywords: 'gau bong teddy bear toy'),
  const EmojiItem(emoji: '🍀', name: 'Cỏ 4 lá', category: 'Gợi ý', keywords: 'co 4 la clover lucky may man'),
  const EmojiItem(emoji: '🌸', name: 'Hoa anh đào', category: 'Gợi ý', keywords: 'hoa anh dao flower sakura cherry blossom'),
  const EmojiItem(emoji: '🌈', name: 'Cầu vồng', category: 'Gợi ý', keywords: 'cau vong rainbow sky'),
  const EmojiItem(emoji: '🔥', name: 'Lửa cháy', category: 'Gợi ý', keywords: 'lua chay fire hot burn'),
  const EmojiItem(emoji: '⚡', name: 'Tia chớp', category: 'Gợi ý', keywords: 'tia chop lightning electric'),
  const EmojiItem(emoji: '📚', name: 'Sách vở', category: 'Gợi ý', keywords: 'sach vo books study learn hoc'),
  const EmojiItem(emoji: '📖', name: 'Sách mở', category: 'Gợi ý', keywords: 'sach mo open book reading doc'),
  const EmojiItem(emoji: '✏️', name: 'Bút chì', category: 'Gợi ý', keywords: 'but chi pencil write viet'),
  const EmojiItem(emoji: '📌', name: 'Ghim đỏ', category: 'Gợi ý', keywords: 'ghim do pin note note label'),
  const EmojiItem(emoji: '🎨', name: 'Bảng vẽ', category: 'Gợi ý', keywords: 'bang ve palette art paint hoa si'),
  const EmojiItem(emoji: '🏷️', name: 'Thẻ tag', category: 'Gợi ý', keywords: 'the tag label price nhan'),
  const EmojiItem(emoji: '💡', name: 'Bóng đèn', category: 'Gợi ý', keywords: 'bong den light bulb idea y tuong sang tao'),
  const EmojiItem(emoji: '🎯', name: 'Mục tiêu', category: 'Gợi ý', keywords: 'muc tieu target goal bullseye'),
  const EmojiItem(emoji: '🚀', name: 'Tên lửa', category: 'Gợi ý', keywords: 'ten lua rocket space fly'),
  const EmojiItem(emoji: '🇻🇳', name: 'Việt Nam', category: 'Gợi ý', keywords: 'viet nam vietnam vn co do sao vang flag cờ'),
  const EmojiItem(emoji: '🇬🇧', name: 'Vương quốc Anh', category: 'Gợi ý', keywords: 'vuong quoc anh uk england united kingdom english flag cờ'),
  const EmojiItem(emoji: '🇺🇸', name: 'Hoa Kỳ', category: 'Gợi ý', keywords: 'hoa ky my usa us america flag cờ'),
  const EmojiItem(emoji: '🇯🇵', name: 'Nhật Bản', category: 'Gợi ý', keywords: 'nhat ban japan japanese jp flag cờ'),
  const EmojiItem(emoji: '🇰🇷', name: 'Hàn Quốc', category: 'Gợi ý', keywords: 'han quoc korea south korea flag cờ'),

  // Mặt cười & Cảm xúc
  const EmojiItem(emoji: '😀', name: 'Cười tươi', category: 'Mặt cười', keywords: 'cuoi grin smile happy vui'),
  const EmojiItem(emoji: '😃', name: 'Mặt cười lớn', category: 'Mặt cười', keywords: 'cuoi to happy smile'),
  const EmojiItem(emoji: '😄', name: 'Cười tít mắt', category: 'Mặt cười', keywords: 'cuoi tit mat happy'),
  const EmojiItem(emoji: '😁', name: 'Cười toe toét', category: 'Mặt cười', keywords: 'cuoi rang grin'),
  const EmojiItem(emoji: '😆', name: 'Cười khúc khích', category: 'Mặt cười', keywords: 'cuoi ha ha laugh'),
  const EmojiItem(emoji: '😅', name: 'Cười toát mồ hôi', category: 'Mặt cười', keywords: 'cuoi ngai sweat smile'),
  const EmojiItem(emoji: '🤣', name: 'Cười lăn lộn', category: 'Mặt cười', keywords: 'cuoi bo rofl haha lol'),
  const EmojiItem(emoji: '😂', name: 'Cười ra nước mắt', category: 'Mặt cười', keywords: 'cuoi khoc joy laugh tears'),
  const EmojiItem(emoji: '🙂', name: 'Mỉm cười nhẹ', category: 'Mặt cười', keywords: 'mim cuoi slightly smile'),
  const EmojiItem(emoji: '😉', name: 'Nháy mắt', category: 'Mặt cười', keywords: 'nhay mat wink'),
  const EmojiItem(emoji: '😊', name: 'Mỉm cười ấm áp', category: 'Mặt cười', keywords: 'cuoi ngai blush happy'),
  const EmojiItem(emoji: '😇', name: 'Thiên thần', category: 'Mặt cười', keywords: 'thien than angel innocent'),
  const EmojiItem(emoji: '🥰', name: 'Mặt yêu thương', category: 'Mặt cười', keywords: 'yeu thuong love heart in love'),
  const EmojiItem(emoji: '😍', name: 'Mắt trái tim', category: 'Mặt cười', keywords: 'mat trai tim heart eyes love me'),
  const EmojiItem(emoji: '🤩', name: 'Mắt ngôi sao', category: 'Mặt cười', keywords: 'mat ngoi sao star struck wow'),
  const EmojiItem(emoji: '😘', name: 'Hôn gió', category: 'Mặt cười', keywords: 'hon gio kiss blow kiss'),
  const EmojiItem(emoji: '😋', name: 'Ngon miệng', category: 'Mặt cười', keywords: 'ngon mieng yummy delicious'),
  const EmojiItem(emoji: '😛', name: 'Lè lưỡi', category: 'Mặt cười', keywords: 'le luoi tongue playful'),
  const EmojiItem(emoji: '😜', name: 'Nháy mắt lè lưỡi', category: 'Mặt cười', keywords: 'nhay mat le luoi crazy silly'),
  const EmojiItem(emoji: '🤪', name: 'Tưng tửng', category: 'Mặt cười', keywords: 'dien khung zany crazy'),
  const EmojiItem(emoji: '🤗', name: 'Ôm ấm áp', category: 'Mặt cười', keywords: 'om hug hugging warm'),
  const EmojiItem(emoji: '🤭', name: 'Cười che miệng', category: 'Mặt cười', keywords: 'cuoi che mieng giggle oops'),
  const EmojiItem(emoji: '🤫', name: 'Suỵt giữ im lặng', category: 'Mặt cười', keywords: 'suyt im lang shh quiet secret'),
  const EmojiItem(emoji: '🤔', name: 'Suy nghĩ', category: 'Mặt cười', keywords: 'suy nghi thinking ponder hmm'),
  const EmojiItem(emoji: '😎', name: 'Ngầu đeo kính râm', category: 'Mặt cười', keywords: 'ngau deo kinh cool sunglasses'),
  const EmojiItem(emoji: '🤓', name: 'Mọt sách', category: 'Mặt cười', keywords: 'mot sach nerd geek study'),
  const EmojiItem(emoji: '🧐', name: 'Soi xét', category: 'Mặt cười', keywords: 'soi kinh monocle smart curious'),
  const EmojiItem(emoji: '🥳', name: 'Tiệc tùng', category: 'Mặt cười', keywords: 'tiec tung party celebrate sinh nhat'),
  const EmojiItem(emoji: '🥺', name: 'Cầu xin mắt to', category: 'Mặt cười', keywords: 'cau xin pleading cute please'),
  const EmojiItem(emoji: '😭', name: 'Khóc to', category: 'Mặt cười', keywords: 'khoc to cry sob sad buon'),
  const EmojiItem(emoji: '😱', name: 'Hét lên kinh ngạc', category: 'Mặt cười', keywords: 'het kinh ngac scream shocked wow'),
  const EmojiItem(emoji: '🤯', name: 'Nổ não', category: 'Mặt cười', keywords: 'no nao mind blown shocked'),
  const EmojiItem(emoji: '😴', name: 'Ngủ say', category: 'Mặt cười', keywords: 'ngu say sleeping zzz tired'),
  const EmojiItem(emoji: '🤠', name: 'Cao bồi', category: 'Mặt cười', keywords: 'cao boi cowboy hat'),

  // Động vật & Thiên nhiên
  const EmojiItem(emoji: '🐶', name: 'Mặt cún', category: 'Động vật', keywords: 'cho cun dog puppy pet'),
  const EmojiItem(emoji: '🐱', name: 'Mặt mèo', category: 'Động vật', keywords: 'meo cat kitty pet'),
  const EmojiItem(emoji: '🐭', name: 'Chuột nhắt', category: 'Động vật', keywords: 'chuot mouse rat'),
  const EmojiItem(emoji: '🐹', name: 'Hamster', category: 'Động vật', keywords: 'chuot hamster pet'),
  const EmojiItem(emoji: '🐰', name: 'Thỏ con', category: 'Động vật', keywords: 'tho con rabbit bunny'),
  const EmojiItem(
      emoji: '🦊', name: 'Cáo', category: 'Động vật', keywords: 'cao fox red'),
  const EmojiItem(emoji: '🐻', name: 'Gấu', category: 'Động vật', keywords: 'gau bear brown'),
  const EmojiItem(emoji: '🐼', name: 'Panda', category: 'Động vật', keywords: 'gau truc panda bear'),
  const EmojiItem(emoji: '🐨', name: 'Koala', category: 'Động vật', keywords: 'koala uc australia'),
  const EmojiItem(emoji: '🐯', name: 'Mặt hổ', category: 'Động vật', keywords: 'ho tiger cọp'),
  const EmojiItem(emoji: '🦁', name: 'Sư tử', category: 'Động vật', keywords: 'su tu lion king'),
  const EmojiItem(emoji: '🐮', name: 'Bò sữa', category: 'Động vật', keywords: 'bo sua cow milk'),
  const EmojiItem(emoji: '🐷', name: 'Heo con', category: 'Động vật', keywords: 'heo pig lợn pink'),
  const EmojiItem(emoji: '🐸', name: 'Ếch cốm', category: 'Động vật', keywords: 'ech frog green'),
  const EmojiItem(emoji: '🐵', name: 'Khỉ con', category: 'Động vật', keywords: 'khi monkey chimp'),
  const EmojiItem(emoji: '🐔', name: 'Gà mái', category: 'Động vật', keywords: 'ga chicken bird'),
  const EmojiItem(emoji: '🐧', name: 'Chim cánh cụt', category: 'Động vật', keywords: 'chim canh cut penguin cute'),
  const EmojiItem(emoji: '🐦', name: 'Chim non', category: 'Động vật', keywords: 'chim bird blue'),
  const EmojiItem(emoji: '🐤', name: 'Gà con', category: 'Động vật', keywords: 'ga con chick yellow'),
  const EmojiItem(emoji: '🦆', name: 'Vịt trời', category: 'Động vật', keywords: 'vit duck bird'),
  const EmojiItem(emoji: '🦉', name: 'Cú mèo', category: 'Động vật', keywords: 'cu meo owl smart night'),
  const EmojiItem(emoji: '🦄', name: 'Kỳ lân', category: 'Động vật', keywords: 'ky lan unicorn magic pony'),
  const EmojiItem(emoji: '🐝', name: 'Ong mật', category: 'Động vật', keywords: 'ong bee honey insect'),
  const EmojiItem(emoji: '🦋', name: 'Bướm xinh', category: 'Động vật', keywords: 'buom butterfly insect beauty'),
  const EmojiItem(emoji: '🐢', name: 'Rùa', category: 'Động vật', keywords: 'rua turtle slow'),
  const EmojiItem(emoji: '🐬', name: 'Cá heo', category: 'Động vật', keywords: 'ca heo dolphin ocean biển'),
  const EmojiItem(emoji: '🐳', name: 'Cá voi', category: 'Động vật', keywords: 'ca voi whale ocean'),
  const EmojiItem(emoji: '🦭', name: 'Hải cẩu', category: 'Động vật', keywords: 'hai cau seal ocean'),
  const EmojiItem(emoji: '🦥', name: 'Con lười', category: 'Động vật', keywords: 'con luoi sloth slow cute'),
  const EmojiItem(emoji: '🦔', name: 'Nhím gai', category: 'Động vật', keywords: 'nhim hedgehog spine cute'),
  const EmojiItem(emoji: '🌵', name: 'Xương rồng', category: 'Động vật', keywords: 'xuong rong cactus desert'),
  const EmojiItem(emoji: '🌲', name: 'Cây thông', category: 'Động vật', keywords: 'cay thong pine tree forest'),
  const EmojiItem(emoji: '🌻', name: 'Hoa hướng dương', category: 'Động vật', keywords: 'hoa huong duong sunflower sun'),
  const EmojiItem(emoji: '🌷', name: 'Hoa tulip', category: 'Động vật', keywords: 'hoa tulip flower'),
  const EmojiItem(emoji: '🍄', name: 'Nấm đỏ', category: 'Động vật', keywords: 'nam mushroom red mario'),

  // Đồ ăn & Thức uống
  const EmojiItem(emoji: '🍏', name: 'Táo xanh', category: 'Đồ ăn', keywords: 'tao xanh green apple fruit'),
  const EmojiItem(emoji: '🍎', name: 'Táo đỏ', category: 'Đồ ăn', keywords: 'tao do red apple fruit'),
  const EmojiItem(emoji: '🍐', name: 'Quả lê', category: 'Đồ ăn', keywords: 'qua le pear fruit'),
  const EmojiItem(emoji: '🍊', name: 'Quả cam', category: 'Đồ ăn', keywords: 'qua cam orange fruit'),
  const EmojiItem(emoji: '🍋', name: 'Quả chanh', category: 'Đồ ăn', keywords: 'qua chanh lemon fruit chua'),
  const EmojiItem(emoji: '🍌', name: 'Quả chuối', category: 'Đồ ăn', keywords: 'qua chuoi banana fruit'),
  const EmojiItem(emoji: '🍉', name: 'Dưa hấu', category: 'Đồ ăn', keywords: 'dua hau watermelon fruit summer'),
  const EmojiItem(emoji: '🍇', name: 'Nho tím', category: 'Đồ ăn', keywords: 'nho grape fruit wine'),
  const EmojiItem(emoji: '🍓', name: 'Dâu tây', category: 'Đồ ăn', keywords: 'dau tay strawberry fruit sweet'),
  const EmojiItem(emoji: '🫐', name: 'Việt quất', category: 'Đồ ăn', keywords: 'viet quat blueberry fruit berry'),
  const EmojiItem(emoji: '🍒', name: 'Quả anh đào', category: 'Đồ ăn', keywords: 'anh dao cherry fruit red'),
  const EmojiItem(emoji: '🍑', name: 'Quả đào', category: 'Đồ ăn', keywords: 'qua dao peach fruit pink'),
  const EmojiItem(emoji: '🥭', name: 'Quả xoài', category: 'Đồ ăn', keywords: 'qua xoai mango fruit sweet'),
  const EmojiItem(emoji: '🍍', name: 'Quả dứa', category: 'Đồ ăn', keywords: 'qua dua thom pineapple fruit'),
  const EmojiItem(emoji: '🥥', name: 'Quả dừa', category: 'Đồ ăn', keywords: 'qua dua coconut tropical'),
  const EmojiItem(emoji: '🥑', name: 'Quả bơ', category: 'Đồ ăn', keywords: 'qua bo avocado healthy'),
  const EmojiItem(emoji: '🌽', name: 'Bắp ngô', category: 'Đồ ăn', keywords: 'bap ngo corn vegetable'),
  const EmojiItem(emoji: '🥕', name: 'Cà rốt', category: 'Đồ ăn', keywords: 'ca rot carrot rabbit vegetable'),
  const EmojiItem(emoji: '🥐', name: 'Bánh sừng bò', category: 'Đồ ăn', keywords: 'croissant banh sung bo bakery bread'),
  const EmojiItem(emoji: '🍞', name: 'Bánh mì gối', category: 'Đồ ăn', keywords: 'banh mi bread toast bakery'),
  const EmojiItem(emoji: '🥖', name: 'Bánh mì que', category: 'Đồ ăn', keywords: 'banh mi que baguette bread french'),
  const EmojiItem(emoji: '🧀', name: 'Phô mai', category: 'Đồ ăn', keywords: 'pho mai cheese mouse dairy'),
  const EmojiItem(emoji: '🍳', name: 'Trứng ốp la', category: 'Đồ ăn', keywords: 'trung op la fried egg breakfast'),
  const EmojiItem(emoji: '🥞', name: 'Bánh pancake', category: 'Đồ ăn', keywords: 'pancake banh kep sweet'),
  const EmojiItem(emoji: '🧇', name: 'Bánh waffle', category: 'Đồ ăn', keywords: 'waffle banh to ong sweet'),
  const EmojiItem(emoji: '🍔', name: 'Hamburger', category: 'Đồ ăn', keywords: 'burger hamburger fast food bo'),
  const EmojiItem(emoji: '🍟', name: 'Khoai tây chiên', category: 'Đồ ăn', keywords: 'khoai tay chien french fries fast food'),
  const EmojiItem(emoji: '🍕', name: 'Bánh Pizza', category: 'Đồ ăn', keywords: 'pizza italian fast food cheese'),
  const EmojiItem(emoji: '🥪', name: 'Sandwich', category: 'Đồ ăn', keywords: 'sandwich banh mi kep bread'),
  const EmojiItem(emoji: '🌮', name: 'Bánh Taco', category: 'Đồ ăn', keywords: 'taco mexican food'),
  const EmojiItem(emoji: '🍜', name: 'Mì Ramen', category: 'Đồ ăn', keywords: 'mi ramen noodles soup phở'),
  const EmojiItem(emoji: '🍣', name: 'Sushi Nhật', category: 'Đồ ăn', keywords: 'sushi japanese fish food'),
  const EmojiItem(emoji: '🍦', name: 'Kem ốc quế', category: 'Đồ ăn', keywords: 'kem oc que ice cream sweet cold'),
  const EmojiItem(emoji: '🍩', name: 'Bánh Donut', category: 'Đồ ăn', keywords: 'donut banh ran sweet ring'),
  const EmojiItem(emoji: '🍪', name: 'Bánh quy Cookie', category: 'Đồ ăn', keywords: 'cookie banh quy chocolate biscuit'),
  const EmojiItem(emoji: '🎂', name: 'Bánh sinh nhật', category: 'Đồ ăn', keywords: 'banh sinh nhat birthday cake party'),
  const EmojiItem(emoji: '🍰', name: 'Miếng bánh kem', category: 'Đồ ăn', keywords: 'banh kem shortcake sweet slice'),
  const EmojiItem(emoji: '🍫', name: 'Thanh Socola', category: 'Đồ ăn', keywords: 'socola chocolate bar sweet'),
  const EmojiItem(emoji: '🍬', name: 'Kẹo ngọt', category: 'Đồ ăn', keywords: 'keo candy sweet sugar'),
  const EmojiItem(emoji: '🍭', name: 'Kẹo mút', category: 'Đồ ăn', keywords: 'keo mut lollipop candy sweet'),
  const EmojiItem(emoji: '🍿', name: 'Bắp rang bơ', category: 'Đồ ăn', keywords: 'bap rang bo popcorn cinema movie'),
  const EmojiItem(emoji: '☕', name: 'Cốc cà phê', category: 'Đồ ăn', keywords: 'ca phe coffee cafe cup hot'),
  const EmojiItem(emoji: '🧋', name: 'Trà sữa trân châu', category: 'Đồ ăn', keywords: 'tra sua boba bubble tea milk tea'),

  // Đồ vật & Học tập
  const EmojiItem(emoji: '📚', name: 'Chồng sách', category: 'Học tập', keywords: 'sach vo books library study school hoc tap'),
  const EmojiItem(emoji: '📖', name: 'Sách đang mở', category: 'Học tập', keywords: 'sach mo open book read reading doc'),
  const EmojiItem(emoji: '📓', name: 'Sổ tay', category: 'Học tập', keywords: 'so tay notebook diary ghi chep'),
  const EmojiItem(emoji: '✏️', name: 'Bút chì', category: 'Học tập', keywords: 'but chi pencil write viet ve'),
  const EmojiItem(emoji: '✒️', name: 'Bút máy', category: 'Học tập', keywords: 'but may fountain pen ink mực'),
  const EmojiItem(emoji: '📝', name: 'Giấy note', category: 'Học tập', keywords: 'giay ghi chu memo note write task'),
  const EmojiItem(emoji: '📌', name: 'Ghim đỏ', category: 'Học tập', keywords: 'ghim do pin thumbtack note'),
  const EmojiItem(emoji: '📍', name: 'Ghim tròn', category: 'Học tập', keywords: 'ghim tron round pin map vi tri'),
  const EmojiItem(emoji: '📎', name: 'Kẹp giấy', category: 'Học tập', keywords: 'kep giay paperclip office'),
  const EmojiItem(emoji: '📏', name: 'Thước thẳng', category: 'Học tập', keywords: 'thuoc thang ruler math do'),
  const EmojiItem(emoji: '📐', name: 'Thước ê ke', category: 'Học tập', keywords: 'thuoc eke triangle ruler math'),
  const EmojiItem(emoji: '🎨', name: 'Bảng màu vẽ', category: 'Học tập', keywords: 'bang mau palette art paint artist'),
  const EmojiItem(emoji: '🖌️', name: 'Cọ vẽ', category: 'Học tập', keywords: 'co ve paintbrush art'),
  const EmojiItem(emoji: '✂️', name: 'Kéo cắt', category: 'Học tập', keywords: 'keo cat scissors craft cut'),
  const EmojiItem(emoji: '💡', name: 'Bóng đèn sáng', category: 'Học tập', keywords: 'bong den idea bulb light y tuong smart'),
  const EmojiItem(emoji: '🔍', name: 'Kính lúp', category: 'Học tập', keywords: 'kinh lup magnifying glass search tim kiem'),
  const EmojiItem(emoji: '🔬', name: 'Kính hiển vi', category: 'Học tập', keywords: 'kinh hien vi microscope science lab'),
  const EmojiItem(emoji: '🔭', name: 'Kính thiên văn', category: 'Học tập', keywords: 'kinh thien van telescope star galaxy'),
  const EmojiItem(emoji: '💻', name: 'Laptop máy tính', category: 'Học tập', keywords: 'laptop may tinh computer code tech work'),
  const EmojiItem(emoji: '📱', name: 'Điện thoại iPhone', category: 'Học tập', keywords: 'dien thoai phone iphone mobile'),
  const EmojiItem(emoji: '🎧', name: 'Tai nghe chụp', category: 'Học tập', keywords: 'tai nghe headphones music podcast listen'),
  const EmojiItem(emoji: '⏰', name: 'Đồng hồ báo thức', category: 'Học tập', keywords: 'dong ho bao thuc alarm clock time'),
  const EmojiItem(emoji: '🏆', name: 'Cúp vàng', category: 'Học tập', keywords: 'cup vang trophy winner first champion nhat'),
  const EmojiItem(emoji: '🥇', name: 'Huy chương vàng', category: 'Học tập', keywords: 'huy chuong vang gold medal 1st champion'),
  const EmojiItem(emoji: '🎯', name: 'Bia mục tiêu', category: 'Học tập', keywords: 'bia muc tieu target bullseye goal hit'),
  const EmojiItem(emoji: '🏷️', name: 'Thẻ tag nhãn', category: 'Học tập', keywords: 'the tag label sticker price nhan'),

  // Biểu tượng & Trái tim
  const EmojiItem(emoji: '💖', name: 'Tim lấp lánh', category: 'Biểu tượng', keywords: 'tim lap lanh sparkling heart love'),
  const EmojiItem(emoji: '❤️', name: 'Trái tim đỏ', category: 'Biểu tượng', keywords: 'trai tim do red heart love yeu'),
  const EmojiItem(emoji: '🧡', name: 'Tim cam', category: 'Biểu tượng', keywords: 'tim cam orange heart'),
  const EmojiItem(emoji: '💛', name: 'Tim vàng', category: 'Biểu tượng', keywords: 'tim vang yellow heart'),
  const EmojiItem(emoji: '💚', name: 'Tim xanh lá', category: 'Biểu tượng', keywords: 'tim xanh la green heart nature'),
  const EmojiItem(emoji: '💙', name: 'Tim xanh dương', category: 'Biểu tượng', keywords: 'tim xanh duong blue heart'),
  const EmojiItem(emoji: '💜', name: 'Tim tím', category: 'Biểu tượng', keywords: 'tim tim purple heart'),
  const EmojiItem(emoji: '🤍', name: 'Tim trắng', category: 'Biểu tượng', keywords: 'tim trang white heart peace'),
  const EmojiItem(emoji: '✨', name: 'Ánh sao lấp lánh', category: 'Biểu tượng', keywords: 'anh sao lap lanh sparkles magic shine star'),
  const EmojiItem(emoji: '⭐', name: 'Ngôi sao vàng', category: 'Biểu tượng', keywords: 'ngoi sao star yellow rating'),
  const EmojiItem(emoji: '🌟', name: 'Sao rực rỡ', category: 'Biểu tượng', keywords: 'sao ruc ro glowing star sparkle'),
  const EmojiItem(emoji: '💫', name: 'Vòng sao chóng mặt', category: 'Biểu tượng', keywords: 'vong sao dizzy star magic'),
  const EmojiItem(emoji: '🔥', name: 'Ngọn lửa', category: 'Biểu tượng', keywords: 'ngon lua fire hot lit trend streak'),
  const EmojiItem(emoji: '⚡', name: 'Tia chớp sét', category: 'Biểu tượng', keywords: 'tia chop set zap lightning power fast'),
  const EmojiItem(emoji: '💥', name: 'Vụ nổ bùm', category: 'Biểu tượng', keywords: 'vu no bum boom collision burst'),
  const EmojiItem(emoji: '💯', name: 'Điểm 100 tuyệt đối', category: 'Biểu tượng', keywords: 'diem 100 hundred perfect score full'),
  const EmojiItem(emoji: '🎉', name: 'Pháo giấy tiệc', category: 'Biểu tượng', keywords: 'phao giay party popper celebrate chuc mung'),
  const EmojiItem(emoji: '🎀', name: 'Nơ hồng xinh', category: 'Biểu tượng', keywords: 'no hong ribbon bow gift cute'),
  const EmojiItem(emoji: '👑', name: 'Vương miện hoàng gia', category: 'Biểu tượng', keywords: 'vuong mien crown king queen royal vip'),
  const EmojiItem(emoji: '💎', name: 'Kim cương quý', category: 'Biểu tượng', keywords: 'kim cuong gem diamond jewel precious'),
  const EmojiItem(emoji: '🍀', name: 'Cỏ may mắn', category: 'Biểu tượng', keywords: 'co may man clover 4 leaf lucky'),
  const EmojiItem(emoji: '🌈', name: 'Cầu vồng rực rỡ', category: 'Biểu tượng', keywords: 'cau vong rainbow color pride'),
  const EmojiItem(emoji: '☀️', name: 'Mặt trời sáng', category: 'Biểu tượng', keywords: 'mat troi sun sunny bright day'),
  const EmojiItem(emoji: '🌙', name: 'Trăng lưỡi liềm', category: 'Biểu tượng', keywords: 'trang moon night dem'),
  const EmojiItem(emoji: '🎵', name: 'Nốt nhạc', category: 'Biểu tượng', keywords: 'not nhac musical note song audio'),
  const EmojiItem(emoji: '🎶', name: 'Giai điệu âm nhạc', category: 'Biểu tượng', keywords: 'giai dieu am nhac notes music sing'),
  const EmojiItem(emoji: '🔔', name: 'Chuông thông báo', category: 'Biểu tượng', keywords: 'chuong thong bao bell alert notify'),
  const EmojiItem(emoji: '🎁', name: 'Hộp quà tặng', category: 'Biểu tượng', keywords: 'hop qua tang gift present surprise box'),

  // Hoạt động & Thể thao
  const EmojiItem(emoji: '⚽', name: 'Bóng đá', category: 'Hoạt động', keywords: 'bong da soccer football sport'),
  const EmojiItem(emoji: '🏀', name: 'Bóng rổ', category: 'Hoạt động', keywords: 'bong ro basketball sport'),
  const EmojiItem(emoji: '🎾', name: 'Quần vợt tennis', category: 'Hoạt động', keywords: 'tennis quan vot ball sport'),
  const EmojiItem(emoji: '🏸', name: 'Cầu lông', category: 'Hoạt động', keywords: 'cau long badminton sport'),
  const EmojiItem(emoji: '🏓', name: 'Bóng bàn', category: 'Hoạt động', keywords: 'bong ban ping pong table tennis'),
  const EmojiItem(emoji: '🛹', name: 'Ván trượt skateboard', category: 'Hoạt động', keywords: 'van truot skateboard skate cool'),
  const EmojiItem(emoji: '🎮', name: 'Tay cầm chơi game', category: 'Hoạt động', keywords: 'tay cam game controller gaming play'),
  const EmojiItem(emoji: '🎲', name: 'Xúc xắc xí ngầu', category: 'Hoạt động', keywords: 'xuc xac die dice game boardgame'),
  const EmojiItem(emoji: '♟️', name: 'Quân cờ vua', category: 'Hoạt động', keywords: 'co vua chess pawn strategy'),
  const EmojiItem(emoji: '🎸', name: 'Đàn Guitar', category: 'Hoạt động', keywords: 'dan guitar music rock acoustic'),
  const EmojiItem(emoji: '🎹', name: 'Đàn Piano phím', category: 'Hoạt động', keywords: 'dan piano keyboard music song'),

  // Du lịch & Địa điểm
  const EmojiItem(emoji: '✈️', name: 'Máy bay', category: 'Du lịch', keywords: 'may bay airplane plane travel flight bay'),
  const EmojiItem(emoji: '🚀', name: 'Tên lửa bay', category: 'Du lịch', keywords: 'ten lua rocket space fast launch'),
  const EmojiItem(emoji: '🚗', name: 'Xe ô tô đỏ', category: 'Du lịch', keywords: 'xe o to car automobile drive'),
  const EmojiItem(emoji: '🚲', name: 'Xe đạp', category: 'Du lịch', keywords: 'xe dap bicycle bike ride cycle'),
  const EmojiItem(emoji: '🛵', name: 'Xe máy scooter', category: 'Du lịch', keywords: 'xe may motor scooter ride'),
  const EmojiItem(emoji: '⛺', name: 'Lều cắm trại', category: 'Du lịch', keywords: 'leu cam trai tent camping camp outdoor'),
  const EmojiItem(emoji: '🏖️', name: 'Bãi biển nhiệt đới', category: 'Du lịch', keywords: 'bai bien beach summer umbrella sea'),
  const EmojiItem(emoji: '🏝️', name: 'Hòn đảo hoang', category: 'Du lịch', keywords: 'hon dao island tropical ocean'),
  const EmojiItem(emoji: '🏔️', name: 'Núi tuyết', category: 'Du lịch', keywords: 'nui tuyet mountain snow peak climb'),
  const EmojiItem(emoji: '🎡', name: 'Vòng đu quay', category: 'Du lịch', keywords: 'vong du quay ferris wheel park fun'),

  // Quốc kỳ & Cờ các quốc gia (Flags)
  const EmojiItem(emoji: '🇻🇳', name: 'Việt Nam', category: 'Quốc kỳ', keywords: 'viet nam vietnam vn co do sao vang national flag cờ'),
  const EmojiItem(
      emoji: '🇬🇧',
      name: 'Vương quốc Anh',
      category: 'Quốc kỳ',
      keywords:
          'vuong quoc anh uk great britain england united kingdom english co anh cờ'),
  const EmojiItem(emoji: '🇺🇸', name: 'Hoa Kỳ / Mỹ', category: 'Quốc kỳ', keywords: 'hoa ky my usa us america united states american co my cờ'),
  const EmojiItem(emoji: '🇯🇵', name: 'Nhật Bản', category: 'Quốc kỳ', keywords: 'nhat ban japan japanese jp mat troi moc cờ'),
  const EmojiItem(emoji: '🇰🇷', name: 'Hàn Quốc', category: 'Quốc kỳ', keywords: 'han quoc korea south korea korean kr cờ'),
  const EmojiItem(emoji: '🇨🇳', name: 'Trung Quốc', category: 'Quốc kỳ', keywords: 'trung quoc china chinese cn cờ'),
  const EmojiItem(emoji: '🇫🇷', name: 'Pháp', category: 'Quốc kỳ', keywords: 'phap france french fr cờ'),
  const EmojiItem(emoji: '🇩🇪', name: 'Đức', category: 'Quốc kỳ', keywords: 'duc germany german de cờ'),
  const EmojiItem(emoji: '🇪🇸', name: 'Tây Ban Nha', category: 'Quốc kỳ', keywords: 'tay ban nha spain spanish es cờ'),
  const EmojiItem(emoji: '🇮🇹', name: 'Ý / Italia', category: 'Quốc kỳ', keywords: 'y italia italy italian it cờ'),
  const EmojiItem(emoji: '🇷🇺', name: 'Nga', category: 'Quốc kỳ', keywords: 'nga russia russian ru cờ'),
  const EmojiItem(emoji: '🇨🇦', name: 'Canada', category: 'Quốc kỳ', keywords: 'canada ca maple leaf la phong cờ'),
  const EmojiItem(emoji: '🇦🇺', name: 'Úc / Australia', category: 'Quốc kỳ', keywords: 'uc australia aussie au kangaroo cờ'),
  const EmojiItem(emoji: '🇳🇿', name: 'New Zealand', category: 'Quốc kỳ', keywords: 'new zealand nz kiwi cờ'),
  const EmojiItem(emoji: '🇸🇬', name: 'Singapore', category: 'Quốc kỳ', keywords: 'singapore sg cờ'),
  const EmojiItem(emoji: '🇹🇭', name: 'Thái Lan', category: 'Quốc kỳ', keywords: 'thai lan thailand thai th cờ'),
  const EmojiItem(emoji: '🇱🇦', name: 'Lào', category: 'Quốc kỳ', keywords: 'lao laos la cờ'),
  const EmojiItem(emoji: '🇰🇭', name: 'Campuchia', category: 'Quốc kỳ', keywords: 'campuchia cambodia kh angkor cờ'),
  const EmojiItem(emoji: '🇲🇾', name: 'Malaysia', category: 'Quốc kỳ', keywords: 'malaysia my cờ'),
  const EmojiItem(emoji: '🇮🇩', name: 'Indonesia', category: 'Quốc kỳ', keywords: 'indonesia id cờ'),
  const EmojiItem(emoji: '🇵🇭', name: 'Philippines', category: 'Quốc kỳ', keywords: 'philippines ph cờ'),
  const EmojiItem(emoji: '🇮🇳', name: 'Ấn Độ', category: 'Quốc kỳ', keywords: 'an do india indian in cờ'),
  const EmojiItem(emoji: '🇧🇷', name: 'Brazil', category: 'Quốc kỳ', keywords: 'brazil br samba cờ'),
  const EmojiItem(emoji: '🇲🇽', name: 'Mexico', category: 'Quốc kỳ', keywords: 'mexico mx cờ'),
  const EmojiItem(emoji: '🇦🇷', name: 'Argentina', category: 'Quốc kỳ', keywords: 'argentina ar cờ'),
  const EmojiItem(emoji: '🇨🇭', name: 'Thụy Sĩ', category: 'Quốc kỳ', keywords: 'thuy si switzerland ch cờ'),
  const EmojiItem(emoji: '🇸🇪', name: 'Thụy Điển', category: 'Quốc kỳ', keywords: 'thuy dien sweden se cờ'),
  const EmojiItem(emoji: '🇳🇴', name: 'Na Uy', category: 'Quốc kỳ', keywords: 'na uy norway no cờ'),
  const EmojiItem(emoji: '🇫🇮', name: 'Phần Lan', category: 'Quốc kỳ', keywords: 'phan lan finland fi cờ'),
  const EmojiItem(emoji: '🇩🇰', name: 'Đan Mạch', category: 'Quốc kỳ', keywords: 'dan mach denmark dk cờ'),
  const EmojiItem(emoji: '🇳🇱', name: 'Hà Lan', category: 'Quốc kỳ', keywords: 'ha lan netherlands holland nl cờ'),
  const EmojiItem(emoji: '🇧🇪', name: 'Bỉ', category: 'Quốc kỳ', keywords: 'bi belgium be cờ'),
  const EmojiItem(emoji: '🇵🇹', name: 'Bồ Đào Nha', category: 'Quốc kỳ', keywords: 'bo dao nha portugal pt cờ'),
  const EmojiItem(emoji: '🇬🇷', name: 'Hy Lạp', category: 'Quốc kỳ', keywords: 'hy lap greece greek gr cờ'),
  const EmojiItem(emoji: '🇹🇷', name: 'Thổ Nhĩ Kỳ', category: 'Quốc kỳ', keywords: 'tho nhi ky turkey tr cờ'),
  const EmojiItem(emoji: '🇪🇬', name: 'Ai Cập', category: 'Quốc kỳ', keywords: 'ai cap egypt eg kim tu thap cờ'),
  const EmojiItem(emoji: '🇿🇦', name: 'Nam Phi', category: 'Quốc kỳ', keywords: 'nam phi south africa za cờ'),
  const EmojiItem(emoji: '🇸🇦', name: 'Ả Rập Xê Út', category: 'Quốc kỳ', keywords: 'a rap xe ut saudi arabia sa cờ'),
  const EmojiItem(emoji: '🇦🇪', name: 'UAE (Các TVQ Ả Rập)', category: 'Quốc kỳ', keywords: 'uae emirates dubai abu dhabi ae cờ'),
  const EmojiItem(emoji: '🇮🇪', name: 'Ireland', category: 'Quốc kỳ', keywords: 'ireland ie cờ'),
  const EmojiItem(emoji: '🇵🇱', name: 'Ba Lan', category: 'Quốc kỳ', keywords: 'ba lan poland pl cờ'),
  const EmojiItem(emoji: '🇺🇦', name: 'Ukraine', category: 'Quốc kỳ', keywords: 'ukraine ua cờ'),
  const EmojiItem(emoji: '🇨🇿', name: 'Cộng hòa Séc', category: 'Quốc kỳ', keywords: 'sec czech cz cờ'),
  const EmojiItem(emoji: '🇦🇹', name: 'Áo', category: 'Quốc kỳ', keywords: 'ao austria at cờ'),
  const EmojiItem(
      emoji: '🇨🇺', name: 'Cuba', category: 'Quốc kỳ', keywords: 'cuba cu cờ'),
  const EmojiItem(emoji: '🇹🇼', name: 'Đài Loan', category: 'Quốc kỳ', keywords: 'dai loan taiwan tw cờ'),
  const EmojiItem(emoji: '🇭🇰', name: 'Hồng Kông', category: 'Quốc kỳ', keywords: 'hong kong hk cờ'),
  const EmojiItem(emoji: '🇲🇴', name: 'Ma Cao', category: 'Quốc kỳ', keywords: 'ma cao macau mo cờ'),
  const EmojiItem(emoji: '🇪🇺', name: 'Liên minh Châu Âu (EU)', category: 'Quốc kỳ', keywords: 'lien minh chau au european union eu cờ'),
  const EmojiItem(emoji: '🇺🇳', name: 'Liên Hợp Quốc (UN)', category: 'Quốc kỳ', keywords: 'lien hop quoc united nations un cờ'),
  const EmojiItem(emoji: '🏳️‍🌈', name: 'Cờ lục sắc LGBT', category: 'Quốc kỳ', keywords: 'co luc sac rainbow flag pride lgbt cờ'),
  const EmojiItem(emoji: '🏳️‍⚧️', name: 'Cờ chuyển giới', category: 'Quốc kỳ', keywords: 'co chuyen gioi transgender flag pride cờ'),
  const EmojiItem(emoji: '🏴‍☠️', name: 'Cờ hải tặc', category: 'Quốc kỳ', keywords: 'co hai tac pirate flag skull cờ'),
  const EmojiItem(emoji: '🏁', name: 'Cờ ca-rô đua xe', category: 'Quốc kỳ', keywords: 'co ca ro checkered racing flag finish cờ'),
  const EmojiItem(emoji: '🚩', name: 'Cờ tam giác đỏ', category: 'Quốc kỳ', keywords: 'co tam giac do triangular red flag pin cờ'),
  const EmojiItem(emoji: '🎌', name: 'Cờ chéo Nhật', category: 'Quốc kỳ', keywords: 'co cheo crossed flags celebration cờ'),
  const EmojiItem(emoji: '🏳️', name: 'Cờ trắng hòa bình', category: 'Quốc kỳ', keywords: 'co trang white flag peace surrender cờ'),
  const EmojiItem(emoji: '🏴', name: 'Cờ đen', category: 'Quốc kỳ', keywords: 'co den black flag cờ'),
];
