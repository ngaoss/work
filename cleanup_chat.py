import re

file_path = r'lib\features\chat\presentation\pages\chat_detail_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Normalize to \n for regex then back to \r\n
content = content.replace('\r\n', '\n')

pattern = r'class _ReplyBanner extends StatelessWidget \{.*?^\}'
blocks = list(re.finditer(pattern, content, re.MULTILINE | re.DOTALL))

if len(blocks) > 1:
    print(f"Found {len(blocks)} _ReplyBanner blocks. Keeping only the first one.")
    # Keep only the first block
    new_content = content[:blocks[0].end()] + content[blocks[-1].end():]
    
    # Also ensure there aren't extra empty lines where blocks were
    new_content = re.sub(r'\n\n\n+', '\n\n', new_content)
    
    with open(file_path, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write(new_content)
    print("Cleaned up duplicates.")
else:
    print("No duplicates found.")
