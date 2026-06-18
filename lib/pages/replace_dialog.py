import os
import glob
import re

def extract_container(text, start_idx):
    # start_idx should point to the 'C' in Container( or 'c' in child:
    # but let's just find the first Return or => then match the widget.
    pass

def replace_in_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # We will use a brace matching parser to find showModalBottomSheet
    # and replace it.
    output = []
    idx = 0
    changed = False

    while True:
        idx_show = content.find("showModalBottomSheet", idx)
        if idx_show == -1:
            output.append(content[idx:])
            break

        # found showModalBottomSheet, let's find the matching parenthesis
        paren_start = content.find("(", idx_show)
        if paren_start == -1:
            output.append(content[idx:])
            break

        output.append(content[idx:idx_show])
        
        # match braces for the arguments of showModalBottomSheet
        depth = 1
        curr = paren_start + 1
        while curr < len(content) and depth > 0:
            if content[curr] == '(': depth += 1
            elif content[curr] == ')': depth -= 1
            curr += 1
        
        paren_end = curr
        
        args = content[paren_start+1:paren_end-1]
        
        # Now we extract the returned widget of the builder
        # usually builder: (context) { return Container(...); }
        # or builder: (_) => Container(...)
        # let's look for "return Container" or "=> Container"
        
        container_start_idx = args.find("Container(")
        if container_start_idx == -1:
            container_start_idx = args.find("Container\n")
        
        if container_start_idx != -1:
            # Match the container braces
            cdepth = 1
            ccurr = args.find("(", container_start_idx) + 1
            while ccurr < len(args) and cdepth > 0:
                if args[ccurr] == '(': cdepth += 1
                elif args[ccurr] == ')': cdepth -= 1
                ccurr += 1
            
            container_str = args[container_start_idx:ccurr]
            
            replacement = (
                "ScaffoldMessenger.of(context).showSnackBar(\n"
                "        SnackBar(\n"
                "          content: " + container_str + ",\n"
                "          backgroundColor: Colors.transparent,\n"
                "          elevation: 0,\n"
                "          padding: EdgeInsets.zero,\n"
                "        ),\n"
                "      )"
            )
            # check if there's a trailing semicolon after showModalBottomSheet(...)
            # if we removed it, we need to add it, but it might still be there in the main content string.
            # wait, we only removed `showModalBottomSheet(...)`. So the trailing semicolon is in content[paren_end:].
            # that's perfect.
            
            output.append(replacement)
            changed = True
        else:
            # if we couldn't find Container, we must have some other widget. Let's just find what the builder returns
            # Wait, let's be more robust: extract the body of builder function
            match = re.search(r'builder\s*:\s*\([^)]*\)\s*(?:=>|{)(.*)', args, re.DOTALL)
            if match:
                builder_body = match.group(1).strip()
                # If it ended with '}' from a block, remove the trailing '}'
                if args.strip().endswith('}'):
                    builder_body = builder_body[:-1].strip()
                # If there's a return, remove it
                if builder_body.startswith('return '):
                    builder_body = builder_body[7:].strip()
                if builder_body.endswith(';'):
                    builder_body = builder_body[:-1].strip()
                    
                replacement = (
                    "ScaffoldMessenger.of(context).showSnackBar(\n"
                    "        SnackBar(\n"
                    "          content: " + builder_body + ",\n"
                    "          backgroundColor: Colors.transparent,\n"
                    "          elevation: 0,\n"
                    "          padding: EdgeInsets.zero,\n"
                    "        ),\n"
                    "      )"
                )
                output.append(replacement)
                changed = True
            else:
                output.append(content[idx_show:paren_end])
        
        idx = paren_end

    new_content = "".join(output)
    
    # We should also remove Navigator.of(context).pop(); or Navigator.pop(context);
    # ONLY when it's immediately preceding ScaffoldMessenger or when it's in a catch block?
    # No, what if we just remove lines containing Navigator.pop if they are in these specific forms?
    # If the user said "remove the part where we need to manually close the showModalBottomSheet", 
    # and they specifically refer to this, we can try to find `Navigator.pop` and verify context.
    
    # For now, let's write to file ONLY the replacement of showModalBottomSheet.
    if changed:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for f in glob.glob('/home/muhammad/f_absensi/lib/pages/*.dart'):
    replace_in_file(f)

