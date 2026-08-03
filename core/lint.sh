#!/usr/bin/env bash
# @category: System & Runtime Control

_lint_docstrings() {
    ERRORS=0
    WARNINGS=0

    # Terminal formatting colors
    RED="\033[1;31m"
    GREEN="\033[1;32m"
    YELLOW="\033[1;33m"
    BLUE="\033[1;36m"
    NC="\033[0m"

    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}          Llamalias Docstring Linter             ${NC}"
    echo -e "${BLUE}=================================================${NC}\n"

    # Collect all target files in core/ and modules/
    target_files=()
    for file in "${LLAMALIAS_DIR}"/core/*.sh "${LLAMALIAS_DIR}"/modules/*.sh; do
        [[ -f "$file" ]] && target_files+=("$file")
    done

    if [[ ${#target_files[@]} -eq 0 ]]; then
        echo -e "${RED}Error:${NC} No script files found in core/ or modules/."
        exit 1
    fi

    for file in "${target_files[@]}"; do
        rel_path="${file#$LLAMALIAS_DIR/}"
        echo -e "Scanning ${BLUE}${rel_path}${NC}..."

        # 1. Check for module category header
        if ! grep -q -E '^[[:space:]]*#[[:space:]]*@category:' "$file"; then
            echo -e "  ${YELLOW}[WARN]${NC} Missing '# @category:' header tag"
            ((WARNINGS++))
        fi

        # 2. Locate all public command functions (ai-*)
        while IFS=: read -r line_num func_line; do
            # Extract function name from definition
            func_name=$(echo "$func_line" | sed -E 's/^[[:space:]]*(function[[:space:]]+)?([a-zA-Z0-9_-]+).*/\2/')

            # Extract 6 preceding lines to inspect docstrings
            start_line=$((line_num - 6))
            [[ $start_line -lt 1 ]] && start_line=1
           
            context=$(sed -n "${start_line},$((line_num - 1))p" "$file")

            # Parse presence of docstring tags
            cmd_tag=$(echo "$context" | grep -E '^[[:space:]]*#[[:space:]]*@cmd:' | tail -n 1 || true)
            desc_tag=$(echo "$context" | grep -E '^[[:space:]]*#[[:space:]]*@desc:' | tail -n 1 || true)
            usage_tag=$(echo "$context" | grep -E '^[[:space:]]*#[[:space:]]*@usage:' | tail -n 1 || true)

            # Validate @cmd tag
            if [[ -z "$cmd_tag" ]]; then
                echo -e "  ${RED}[ERR]${NC} Line $line_num ($func_name): Missing '# @cmd:' tag"
                ((ERRORS++))
            else
                cmd_val=$(echo "$cmd_tag" | sed -E 's/^[[:space:]]*#[[:space:]]*@cmd:[[:space:]]*//')
                if [[ "$cmd_val" != "$func_name" ]]; then
                    echo -e "  ${RED}[ERR]${NC} Line $line_num ($func_name): Tag '@cmd: $cmd_val' does not match function name"
                    ((ERRORS++))
                fi
            fi

            # Validate @desc tag
            if [[ -z "$desc_tag" ]]; then
                echo -e "  ${RED}[ERR]${NC} Line $line_num ($func_name): Missing '# @desc:' tag"
                ((ERRORS++))
            fi

            # Validate @usage tag
            if [[ -z "$usage_tag" ]]; then
                echo -e "  ${RED}[ERR]${NC} Line $line_num ($func_name): Missing '# @usage:' tag"
                ((ERRORS++))
            fi

        done < <(grep -n -E '^[[:space:]]*(function[[:space:]]+)?ai-[a-zA-Z0-9_-]+[[:space:]]*\(\)' "$file" || true)

    done

    echo ""
    echo -e "${BLUE}=================================================${NC}"
    if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}PASSED:${NC} All modules and commands are perfectly annotated."
        return 0
    elif [[ $ERRORS -eq 0 ]]; then
        echo -e "${YELLOW}PASSED WITH WARNINGS:${NC} 0 errors, $WARNINGS warning(s)."
        return 0
    else
        echo -e "${RED}FAILED:${NC} $ERRORS error(s), $WARNINGS warning(s) found."
        return 1
    fi
}

# @cmd: ai-lint
# @desc: Lint module and core files for properly formatted docstrings
# @usage: ai-lint
ai-lint() {
    _lint_docstrings
}
