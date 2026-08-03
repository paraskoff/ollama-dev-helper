#!/usr/bin/env bash
# @category: System & Runtime Control

# @cmd: ai-help
# @desc: Display overview or detail help for registered CLI commands
# @usage: ai-help [command_name]
ai-help() {
    local target="$1"

    local target_files=()
    for file in "${LLAMALIAS_DIR}"/core/*.sh "${LLAMALIAS_DIR}"/modules/*.sh; do
        [[ -f "$file" ]] && target_files+=("$file")
    done

    if [[ ${#target_files[@]} -eq 0 ]]; then
        echo -e "\033[1;31mError:\033[0m No command files found in core/ or modules/."
        return 1
    fi

    awk -v target="$target" '
        # Reset file-level category fallback when entering a new file
        FILENAME != prev_file {
            category = ""
            prev_file = FILENAME

            n = split(FILENAME, path_parts, "/")
            prev_file_short = path_parts[n]
        }

        # 1. Category Tag
        /^[[:space:]]*#[[:space:]]*@category:/ {
            sub(/^[[:space:]]*#[[:space:]]*@category:[[:space:]]*/, "")
            category = $0
        }

        # 2. Command Tag
        /^[[:space:]]*#[[:space:]]*@cmd:/ {
            sub(/^[[:space:]]*#[[:space:]]*@cmd:[[:space:]]*/, "")
            cmd = $0
        }

        # 3. Description Tag
        /^[[:space:]]*#[[:space:]]*@desc:/ {
            sub(/^[[:space:]]*#[[:space:]]*@desc:[[:space:]]*/, "")
            desc = $0
        }

        # 4. Usage Tag & Accumulation
        /^[[:space:]]*#[[:space:]]*@usage:/ {
            sub(/^[[:space:]]*#[[:space:]]*@usage:[[:space:]]*/, "")
            usage = $0

            if (cmd != "" && desc != "") {
                if (target == "") {
                    # Determine category title
                    cat_title = (category != "" ? category : "Core Infrastructure (" prev_file_short ")")

                    # Record category order if seen for the first time
                    if (!(cat_title in cat_seen)) {
                        cat_seen[cat_title] = 1
                        cat_order[++cat_count] = cat_title
                    }

                    # Append row to the category table buffer
                    cat_tables[cat_title] = cat_tables[cat_title] sprintf("  \033[1;36m%-15s\033[0m %-45s \033[32m%s\033[0m\n", cmd, desc, usage)
                    total_count++
                } else {
                    clean_cmd = cmd;       sub(/^ai-/, "", clean_cmd)
                    clean_target = target; sub(/^ai-/, "", clean_target)

                    if (cmd == target || clean_cmd == clean_target) {
                        found_count++
                        cat_title = (category != "" ? category : "Core Infrastructure")
                        printf "\n\033[1;36m=== Command Details: %s ===\033[0m\n", cmd
                        printf "  \033[1mCategory:\033[0m    %s\n", cat_title
                        printf "  \033[1mDescription:\033[0m %s\n", desc
                        printf "  \033[1mUsage:\033[0m       \033[32m%s\033[0m\n\n", usage
                    }
                }
                cmd = ""; desc = ""; usage = ""
            }
        }

        END {
            if (target == "") {
                print "\033[1;36m===================================================================================\033[0m"
                print "\033[1;36m                             Llamalias Commands                                    \033[0m"
                print "\033[1;36m===================================================================================\033[0m"

                # Print merged categories in order of appearance
                for (i = 1; i <= cat_count; i++) {
                    c_title = cat_order[i]
                    printf "\n\033[1;33m[ %s ]\033[0m\n", c_title
                    printf "%s", cat_tables[c_title]
                }

                print "\033[1;36m===================================================================================\033[0m"
                printf "Total commands loaded: %d\n\n", total_count
            } else if (found_count == 0) {
                printf "\033[1;31mError:\033[0m Command \"%s\" not found in core or module files.\n\n", target
            }
        }
    ' "${target_files[@]}"
}

_generate_markdown() {
# Collect all script files from both core/ and modules/
    local target_files=()
    for file in "${LLAMALIAS_DIR}"/core/*.sh "${LLAMALIAS_DIR}"/modules/*.sh; do
        [[ -f "$file" ]] && target_files+=("$file")
    done

    if [[ ${#target_files[@]} -eq 0 ]]; then
        echo "Error: No script files found in core/ or modules/." >&2
        return 1
    fi

    echo "# Llamalias - CLI Cheat Sheet"
    echo "Auto-generated command documentation."
    echo ""

    awk '
        # Reset file-level category fallback when entering a new file
        FILENAME != prev_file {
            category = ""
            prev_file = FILENAME

            n = split(FILENAME, path_parts, "/")
            prev_file_short = path_parts[n]
        }

        # Anchored matching: Requires line to start with "#"

        # 1. Category Tag
        /^[[:space:]]*#[[:space:]]*@category:/ {
            sub(/^[[:space:]]*#[[:space:]]*@category:[[:space:]]*/, "")
            category = $0
        }

        # 2. Command Tag
        /^[[:space:]]*#[[:space:]]*@cmd:/ {
            sub(/^[[:space:]]*#[[:space:]]*@cmd:[[:space:]]*/, "")
            cmd = "`" $0 "`"
        }

        # 3. Description Tag
        /^[[:space:]]*#[[:space:]]*@desc:/ {
            sub(/^[[:space:]]*#[[:space:]]*@desc:[[:space:]]*/, "")
            desc = $0
        }

        # 4. Usage Tag & Row Accumulation
        /^[[:space:]]*#[[:space:]]*@usage:/ {
            sub(/^[[:space:]]*#[[:space:]]*@usage:[[:space:]]*/, "")
           
            # Escape pipe (|) characters so they do not break Markdown tables
            gsub(/\|/, "\\|")
            usage = "`" $0 "`"

            if (cmd != "" && desc != "") {
                # Determine category title
                cat_title = (category != "" ? category : "Core Infrastructure (" prev_file_short ")")

                # Record category order if seen for the first time
                if (!(cat_title in cat_seen)) {
                    cat_seen[cat_title] = 1
                    cat_order[++cat_count] = cat_title
                }

                # Append row to the category table buffer
                cat_tables[cat_title] = cat_tables[cat_title] "| " cmd " | " desc " | " usage " |\n"

                cmd = ""; desc = ""; usage = ""
            }
        }

        END {
            # Print merged category tables in order of appearance
            for (i = 1; i <= cat_count; i++) {
                c_title = cat_order[i]
                print "## " c_title
                print ""
                print "| Command | Description | Usage |"
                print "| :--- | :--- | :--- |"
                printf "%s", cat_tables[c_title]
                print ""
            }
        }
    ' "${target_files[@]}"
}

# @cmd: ai-cheatsheet
# @desc: Generate a Markdown cheat sheet for all commands across core and modules
# @usage: ai-cheatsheet [--save]
ai-cheatsheet() {
    local output_file="${LLAMALIAS_DIR}/CHEATSHEET.md"

    # Run and output to terminal or write directly to a Markdown file
    if [[ "$1" == "--save" ]]; then
        _generate_markdown > "$output_file"
        echo "Cheat sheet successfully saved to: $output_file"
    else
        _generate_markdown
    fi
}
