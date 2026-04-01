import 'package:flutter/material.dart';

class ProfileSettingsSheet extends StatefulWidget {
  final Map<String, String> initialData;
  final Function(Map<String, String>) onUpdate;

  const ProfileSettingsSheet({
    super.key,
    required this.initialData,
    required this.onUpdate,
  });

  @override
  State<ProfileSettingsSheet> createState() => _ProfileSettingsSheetState();
}

class _ProfileSettingsSheetState extends State<ProfileSettingsSheet> {
  late TextEditingController _phoneController;
  late TextEditingController _birthController;
  late TextEditingController _jobController;
  String _gender = "Nam";

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: widget.initialData["phone"] ?? "",
    );
    _birthController = TextEditingController(
      text: widget.initialData["birth"] ?? "",
    );
    _jobController = TextEditingController(
      text: widget.initialData["job"] ?? "",
    );
    final rawGender = widget.initialData["gender"] ?? "";
    // Normalize gender to only allowed dropdown values
    _gender =
        (rawGender == "Nữ" ||
            rawGender == "Nu" ||
            rawGender == "female" ||
            rawGender == "F")
        ? "Nữ"
        : "Nam"; // default to "Nam" for safety
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _birthController.dispose();
    _jobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthController.text = "${picked.month}/${picked.day}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "CÀI ĐẶT HỒ SƠ",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("SỐ ĐIỆN THOẠI"),
                  _buildTextField(
                    _phoneController,
                    "Nhập số điện thoại",
                    TextInputType.phone,
                  ),

                  const SizedBox(height: 20),
                  _buildLabel("NGÀY SINH"),
                  GestureDetector(
                    onTap: _selectDate,
                    child: AbsorbPointer(
                      child: _buildTextField(
                        _birthController,
                        "mm/dd/yyyy",
                        TextInputType.datetime,
                        suffixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildLabel("GIỚI TÍNH"),
                  _buildDropdown(
                    ["Nam", "Nữ"],
                    _gender,
                    (val) => setState(() => _gender = val!),
                  ),

                  const SizedBox(height: 20),
                  _buildLabel("VỊ TRÍ CÔNG VIỆC"),
                  _buildTextField(
                    _jobController,
                    "Nhập vị trí công việc",
                    TextInputType.text,
                  ),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onUpdate({
                          "phone": _phoneController.text,
                          "birth": _birthController.text,
                          "gender": _gender,
                          "job": _jobController.text,
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "CẬP NHẬT NGAY",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.blueGrey,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    TextInputType type, {
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 15,
          color: Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    List<String> items,
    String current,
    ValueChanged<String?> onChanged,
  ) {
    // Remove duplicates and ensure current value is always in the list
    final uniqueItems = items.toSet().toList();
    final safeValue = uniqueItems.contains(current)
        ? current
        : uniqueItems.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: safeValue,
          decoration: const InputDecoration(border: InputBorder.none),
          items: uniqueItems
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
      ),
    );
  }
}
