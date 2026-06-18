import glob
import re

for filepath in glob.glob('/home/muhammad/f_absensi/lib/pages/*.dart'):
    with open(filepath, 'r') as f:
        content = f.read()

    original_content = content

    # Check if the file contains a ScaffoldMessenger that has a CircularProgressIndicator
    # We can detect this roughly
    snackbars = re.findall(r'ScaffoldMessenger\.of\(context\)\.showSnackBar\([\s\S]*?CircularProgressIndicator[\s\S]*?\);', content)
    
    if snackbars:
        # This file had a loading snackbar (previously a loading bottom sheet).
        # We should remove Navigator.of(context).pop(); and Navigator.pop(context); 
        # that were meant to close it. Usually they are right before Navigator.pushReplacementNamed
        # or inside catch blocks.
        
        # But wait! What if the file ALSO has a showDialog for loading?
        # Let's check if the file uses showDialog( for loading
        if 'showDialog(' in content and 'CircularProgressIndicator' in content:
            # Check if CircularProgressIndicator is in showDialog or ScaffoldMessenger
            # If both, only remove `Navigator.pop` if it's strictly related to the SnackBar.
            # Usually, they don't mix `showModalBottomSheet` for loading and `showDialog` for loading in the same file.
            loading_dialogs = re.findall(r'showDialog\([\s\S]*?CircularProgressIndicator[\s\S]*?\);', content)
            if loading_dialogs:
                continue

        # Safe to remove Navigator.of(context).pop(); and Navigator.pop(context);
        # IF they are part of the submit flow.
        # But to be safe, if we are sure it's the loading bottom sheet, in these files (like leave_apply, task_add)
        # we can remove all Navigator.of(context).pop(); and Navigator.pop(context);
        # Let's see what happens.
        content = re.sub(r'Navigator\.of\(context\)\.pop\(\);\s*', '', content)
        content = re.sub(r'Navigator\.pop\(context\);\s*', '', content)
        
        if content != original_content:
            with open(filepath, 'w') as f:
                f.write(content)
            print(f"Removed pops from {filepath}")

