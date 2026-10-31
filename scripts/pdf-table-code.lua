-- Table cells have less horizontal space than prose. Use fvextra's escaped
-- inline verbatim command so literal code can wrap without adding hyphens.
-- Leave prose code, block code and every non-LaTeX output unchanged.
local escapes = {
  ["\\"] = "\\\\", ["{"] = "\\{", ["}"] = "\\}", ["%"] = "\\%",
  ["#"] = "\\#", ["$"] = "\\$", ["&"] = "\\&", ["_"] = "\\_",
  ["~"] = "\\~", ["^"] = "\\^", [" "] = "\\ "
}

function Table(element)
  if not FORMAT:match("latex") then
    return nil
  end
  return element:walk({
    Code = function(code)
      local literal = code.text:gsub(".", function(char)
        return escapes[char] or char
      end)
      return pandoc.RawInline("latex",
        "\\EscVerb[breaklines=true,breakanywhere=true," ..
        "breakanywheresymbolpre={},breakanywheresymbolpost={}]{" .. literal .. "}")
    end
  })
end
