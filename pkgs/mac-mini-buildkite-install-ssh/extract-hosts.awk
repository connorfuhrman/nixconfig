    /^[[:space:]]*Host[[:space:]]+/ {
      if (in_block && block_wanted) { printf "%s", block }
      block = $0 "\n"
      in_block = 1
      block_wanted = 0
      for (i = 2; i <= NF; i++) {
        if ($i ~ /github\.com/ || $i ~ /origin\.cursor\.com/) {
          block_wanted = 1
        }
      }
      next
    }
    {
      if (in_block) { block = block $0 "\n" }
    }
    END {
      if (in_block && block_wanted) { printf "%s", block }
    }
