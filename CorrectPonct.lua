--[[
	 CorrectPonct
	 Copyright (C) 2011 LeSaint

	 To contact me (bug report / evol) : LeSaint_Fansub {at} hotmail {dot} fr
	 This program is free software: you can redistribute it and/or modify
	 it under the terms of the GNU General Public License as published by
	 the Free Software Foundation, either version 3 of the License, or
	 (at your option) any later version.

	 This program is distributed in the hope that it will be useful,
	 but WITHOUT ANY WARRANTY; without even the implied warranty of
	 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	 GNU General Public License for more details.

	 You should have received a copy of the GNU General Public License
	 along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

	script_author = "LeSaint"
	script_version = "1.0 beta2"
	script_name = "Correction Ponctuation v" .. script_version
	script_description = "Corrige la ponctuation du script courant."
	script_modified = "20th November 2011"

	m_Ponctuation = {}
	m_DblePonct = {}
	m_DblePtsnCo = {}
	m_PointVirgule = {}
	m_GuillemetsFR = {}
	eTypeGuillemets = {}

	eTypeGuillemets.GuillemetsFR = 1
	eTypeGuillemets.GuillemetsDroits = 2

	-- Valeurs par défaut
	UseSuspChar = false
	UseRealApostroph = false
	UseEspaceInsec = false
	
	-- function: create_adjust_config
	-- purpose: create config structure for adjust GUI.
	-- @subs: table containing subtitles.
	-- @meta: metatable.
	-- return: config structure.
	function create_ponct_config(subs)
		conf = {
			to = {
				class = "label",
				x = 0, y = 0, width = 4, height = 2,
				label = "Corrige la ponctuation du script courant :"
			},
			t_titre = {
				class = "label",
				x = 0, y = 2, width = 1, height = 2,
				label = "Type de guillemets : "
			},
			t_guil = {
				class = "dropdown", name = "t_guil",
				x = 1, y = 2, width = 2, height = 2,
				items = {"Français (« »)", 'Droits (" ")'}, value = "Français (« »)", hint = "Type de guillemets utilisés."
			},

			EspInsec = {
				class = "checkbox", name = "EspInsec", 
				label = "Utiliser l'espace insécable avant les double ponctuation",
				x = 0, y = 4, width = 4, height = 1,
				value = UseEspaceInsec, hint = "Utiliser l'espace insécable avant les double ponctuation"
			},		
			SuspChar = {
				class = "checkbox", name = "SuspChar", 
				label = "Utiliser … au lieu de ...",
				x = 0, y = 5, width = 1, height = 1,
				value = UseSuspChar, hint = "Utiliser … au lieu de ..."
			},
			Apost = {
				class = "checkbox", name = "Apost", 
				label = 'Utiliser ' .. "’" .. ' au lieu de ' .. "'",
				x = 1, y = 5, width = 1, height = 1,
				value = UseRealApostroph, hint = 'Utiliser ' .. "’" .. ' au lieu de ' .. "'"
			}			
		}
		return conf
	end	
	
	-- function: load_macro_ponct
	-- purpose: Afficher l'IHM de correction de ponctuation.
	-- @subs: table containing subtitles.
	-- @sel: indexes of selected subtitle lines.
	-- return: /
	function load_macro_ponct(subs,sel)
		local IdxGuil
		local buttons = {"OK", "Annuler"}
		ok, config = aegisub.dialog.display(create_ponct_config(subs))
		if ok=="OK" or ok==true then
			if config.t_guil == "Français (« »)" then
				IdxGuil = eTypeGuillemets.GuillemetsFR
			else
				IdxGuil = eTypeGuillemets.GuillemetsDroits
			end
			-- aegisub.log(2,"CorrigePonctuationMain(subs, IdxGuil)\n")
			CorrigePonctuationMain(subs, IdxGuil, config.EspInsec, config.SuspChar, config.Apost)
			aegisub.set_undo_point("Correction ponctuation")
		end			
	end
	
	-- function: InitData
	-- purpose: Initialisation des variables utilisées dans la correction de ponctuation.
	-- return: /	
	function InitData()
	
        table.insert(m_Ponctuation,".")
        table.insert(m_Ponctuation,",")
        table.insert(m_Ponctuation,":")
        table.insert(m_Ponctuation,";")
        table.insert(m_Ponctuation,"!")
        table.insert(m_Ponctuation,"?")
        table.insert(m_Ponctuation,'"')
        table.insert(m_Ponctuation,"«")
        table.insert(m_Ponctuation,"»")
        table.insert(m_Ponctuation,"(")
        table.insert(m_Ponctuation,")")
        table.insert(m_Ponctuation,"'")
		table.insert(m_Ponctuation,"’")
		table.insert(m_Ponctuation,"%")
		
		aegisub.log(5,"#m_Ponctuation: " .. #m_Ponctuation .. "\n")

        table.insert(m_DblePonct,"!")
        table.insert(m_DblePonct,"?")	
		aegisub.log(5,"#m_DblePonct: " .. #m_DblePonct .. "\n")

        table.insert(m_DblePtsnCo,":")
        table.insert(m_DblePtsnCo,";")
		table.insert(m_DblePtsnCo,"%")
		aegisub.log(5,"#m_DblePtsnCo: " .. #m_DblePtsnCo .. "\n")

        table.insert(m_PointVirgule,".")
        table.insert(m_PointVirgule,",")
		aegisub.log(5,"#m_PointVirgule: " .. #m_PointVirgule .. "\n")

        table.insert(m_GuillemetsFR,"«")
        table.insert(m_GuillemetsFR,"»")	
		aegisub.log(5,"#m_GuillemetsFR: " .. #m_GuillemetsFR .. "\n")		
	end

	-- function: CorrigePonctuationMain
	-- purpose: Réaliser la correction du script courant.
	-- @subs: table des sous-titres
	-- @iTypeGuillemets: type de guillemets utilisés (1 = guillemets FR (« ») ; 2 = guillemets anglais (" "))
	-- return: /
	function CorrigePonctuationMain(subs, iTypeGuillemets, iUseEspaceInsec, iUseSuspChar, iUseApost)
	
		local firstlineIdx=nil -- indice de première ligne de sous titre
		local sub
		local Text
		
		InitData()
		
		aegisub.progress.task("Correction de ponctuation en cours")
		aegisub.progress.set(0)
		for i = 1, #subs, 1 do
			sub = subs[i]		
			
			if sub.class=="dialogue" then
				if firstlineIdx == nil then
					firstlineIdx = i
				end
				
				if not sub.comment then
					Text = CorrigePonctLigne(sub.text, iTypeGuillemets, iUseEspaceInsec, iUseSuspChar, iUseApost)
					sub.text = Text
					subs[i] = sub
				end
				
				if firstlineIdx ~= nil then
					aegisub.progress.set((i-firstlineIdx-1) / (#subs-firstlineIdx-1) *100)
				end
			end
		end
	end
	
	-- function: CorrigePonctLigne
	-- purpose: Fonction transformant une ligne en tableau, sur la base d'un séparateur. S'utilise comme toute autre fonction de la classe string.
	-- @iText : texte sur lequel on cherche à corriger la ponctuation
	-- @iTypeGuillements : type de guillemets utilisés (1 = guillemets FR (« ») ; 2 = guillemets anglais (" "))
	-- @return : Ligne avec ponctuation corrigée
	function CorrigePonctLigne(iText, iTypeGuillements, iUseEspaceInsec, iUseSuspChar, iUseApost)
		local MainStr = iText
		local splitstringtext, splitstringtag = {}, {}
		local tmpsplitstring = {}
		local SuspReplacement = "&µ_|£$#"
		local TagReplacement = '¤'
		local ifor1, ifor2
		local tmpstring, tmpstring2
		local ProblemeGuillemets = false
		local mod1
	
		-- Séparation des tags de la chaine de texte :
		-- Préparation des tags consécutifs pour les laisser ensemble :
		aegisub.log(5,"Préparation des tags consécutifs pour les laisser ensemble :\n")
		MainStr = MainStr:Replace('}{', TagReplacement)
		aegisub.log(5,MainStr .. "\n\n")
		
		-- Découper la chaine d'origine :
		aegisub.log(5,"Découper la chaine d'origine :\n")
		splitstringtext = MainStr:split("{")
		aegisub.log(5,MainStr .. "\n\n")
		
		-- Séparation effective des tags et du texte dans splitstringtext et splitstringtags
		aegisub.log(5,"Séparation effective des tags et du texte dans splitstringtext et splitstringtags\n")
		for ifor1= 2, #splitstringtext do
		
			tmpstring = splitstringtext[ifor1]
			tmpsplitstring = tmpstring:split("}")
			tmpstring = "{" .. tmpsplitstring[1]:Replace(TagReplacement, "}{") .. "}"
			table.insert(splitstringtag, tmpstring)
			splitstringtext[ifor1] = tmpsplitstring[2]
		
		end
		aegisub.log(5,MainStr .. "\n\n")
		
		-- On recrée la MainStr en remplaçant les tags 
		aegisub.log(5,"On recrée la MainStr en remplaçant les tags\n")
		MainStr = splitstringtext[1]
		
		for ifor1 =2, #splitstringtext do
			MainStr = MainStr .. TagReplacement .. splitstringtext[ifor1]
		end
		aegisub.log(5,MainStr .. "\n\n")
	
		-- Retrait des espaces bizarres :
		aegisub.log(5,"Retrait des espaces bizarres :\n")
		
        MainStr = MainStr:Replace(" ", " ") -- oui oui... ces deux espaces ne sont pas pareils... et le premier n'est apparemment pas l'insécable...
        MainStr = MainStr:Replace(" ", " ") -- remplacement de l'espace insécable	
		aegisub.log(5,MainStr .. "\n\n")		
		
		-- Retrait des espaces autour des ponctuations :
		aegisub.log(5,"Retrait des espaces autour des ponctuations :\n")
		for ifor1 = 1, #m_Ponctuation do
			tmpstring = m_Ponctuation[ifor1]
			MainStr = MainStr:Replace(" " .. tmpstring, tmpstring)
			MainStr = MainStr:Replace(tmpstring .. " ", tmpstring)
		end
		aegisub.log(5,MainStr .. "\n\n")
		
		-- Ajout des espaces autour des doubles ponctuations :
		aegisub.log(5,"Ajout des espaces autour des doubles ponctuations :\n")
		for ifor1 = 1, #m_DblePonct do
			tmpstring = m_DblePonct[ifor1]
			MainStr = MainStr:Replace(tmpstring, " " .. tmpstring .. " ")
		end		
		aegisub.log(5,MainStr .. "\n\n")
		
		-- Retrait des doubles espaces :
		aegisub.log(5,"Retrait des doubles espaces :\n")
		while MainStr:Contains("  ") do
			MainStr = MainStr:Replace("  ", " ")
		end
		while MainStr:Contains(" " .. TagReplacement .. " ") do
			MainStr = MainStr:Replace(" " .. TagReplacement .. " ", " " .. TagReplacement)
		end
		aegisub.log(5,MainStr .. "\n\n")
		
		if ProblemeGuillemets then
			aegisub.log(5,"Notification de problème de guillemets\n")
			MainStr = "\{ErrGuillemets\}" .. MainStr
		end			
		
		-- On recrée les groupes de ponctuation ! et ?
		aegisub.log(5,"On recrée les groupes de ponctuation ! et ?\n")
		for ifor1 = 1, #m_DblePonct do
			for ifor2 = 1, #m_DblePonct do
				while MainStr:Contains(m_DblePonct[ifor1] .. " " .. m_DblePonct[ifor2]) do
					MainStr = MainStr:Replace(m_DblePonct[ifor1] .. " " .. m_DblePonct[ifor2], m_DblePonct[ifor1] .. m_DblePonct[ifor2])
				end
				while MainStr:Contains(m_DblePonct[ifor1] .. " " .. TagReplacement .. m_DblePonct[ifor2]) do
					MainStr = MainStr:Replace(m_DblePonct[ifor1] .. " " .. TagReplacement .. m_DblePonct[ifor2], m_DblePonct[ifor1] .. TagReplacement .. m_DblePonct[ifor2])
				end
				while MainStr:Contains(m_DblePonct[ifor1] .. TagReplacement .. " " .. m_DblePonct[ifor2]) do
					MainStr = MainStr:Replace(m_DblePonct[ifor1] .. TagReplacement .. " " .. m_DblePonct[ifor2], m_DblePonct[ifor1] .. TagReplacement .. m_DblePonct[ifor2])
				end			
			end
		end
		aegisub.log(5,MainStr .. "\n\n")
		
		-- Gestion des points de suspension :
		aegisub.log(5,"Gestion des points de suspension :\n")
		MainStr = MainStr:Replace("…", "..")
		while MainStr:Contains("...") do
			MainStr = MainStr:Replace("...", "..")
		end		
		aegisub.log(5,MainStr .. "\n\n")

		-- On remplace les points de suspension pour les différencier des points :
		aegisub.log(5,"On remplace les points de suspension pour les différencier des points :\n")
		MainStr = MainStr:Replace("..", SuspReplacement)
		aegisub.log(5,MainStr .. "\n\n")

		-- On traite le cas des parenthèses :
		aegisub.log(5,"On traite le cas des parenthèses :\n")
		MainStr = MainStr:Replace("(", " (")
		MainStr = MainStr:Replace(")", ") ")
		aegisub.log(5,MainStr .. "\n\n")
		
		-- On traite le cas des doubles ponctuations :
		aegisub.log(5,"On traite le cas des doubles ponctuations :\n")
		for ifor1 = 1, #m_DblePtsnCo do
			tmpstring = m_DblePtsnCo[ifor1]
			MainStr = MainStr:Replace(tmpstring, " " .. tmpstring .. " ")
		end	
		aegisub.log(5,MainStr .. "\n\n")		

		-- On rajoute les espaces autour des guillemets FR :
		aegisub.log(5,"On rajoute les espaces autour des guillemets FR :\n")
		for ifor1 = 1, #m_GuillemetsFR do
			tmpstring = m_GuillemetsFR[ifor1]
			MainStr = MainStr:Replace(tmpstring, " " .. tmpstring .. " ")
		end			
		aegisub.log(5,MainStr .. "\n\n")
		
		-- On remplace les guillemets anglais par des guillemets droits :
		aegisub.log(5,"On remplace les guillemets anglais par des guillemets droits :\n")
		MainStr = MainStr:Replace('“', '"') -- remplacement du guillemet anglais d'ouverture
		MainStr = MainStr:Replace('”', '"') -- remplacement du guillemet anglais de fermeture
		aegisub.log(5,MainStr .. "\n\n")
		
		-- On remplace les guillemets anglais par des français :
		aegisub.log(5,"On remplace les guillemets anglais par des français :\n")
		tmpsplitstring = nil
		mod1 = 0
		if MainStr:Contains('"') then
			tmpsplitstring = MainStr:split('"')
			mod1 = #tmpsplitstring % 2
		end
		aegisub.log(5,MainStr .. "\n\n")
		
		-- Génération de la phrase avec les nouveaux guillemets :
		aegisub.log(5,"Génération de la phrase avec les nouveaux guillemets :\n")
		if tmpsplitstring ~= nil then 
			local idxguillemet
		
			tmpstring = tmpsplitstring[1]
			for ifor1 = 2, #tmpsplitstring do
				idxguillemet = 2-((ifor1+1) % 2) -- on converti l'indice en modulo 2 (1 ou 2) pour récupérer l'indice du guillemet dans m_GuillemetsFR
				tmpstring = tmpstring .. " " .. m_GuillemetsFR[idxguillemet] .. " " .. tmpsplitstring[ifor1]
			end
			if mod1 == 0 then
				-- Problème sur le nombre de guillemets trouvés
				aegisub.log(5,"Problème sur le nombre de guillemets trouvés\n")
				ProblemeGuillemets = true
			end		
			MainStr = tmpstring
		end
		aegisub.log(5,MainStr .. "\n\n")
		
		-- Si demandé, on repasse en guillemets droits
		aegisub.log(5,"Si demandé, on repasse en guillemets droits\n")
		if iTypeGuillements == eTypeGuillemets.GuillemetsDroits then
			MainStr = MainStr:Replace("« ", '"')
			MainStr = MainStr:Replace(" »", '"')		
		end
		aegisub.log(5,MainStr .. "\n\n")
		
		-- On traite le cas des points et des virgules :
		aegisub.log(5,"On traite le cas des points et des virgules :\n")
		for ifor1 = 1, #m_PointVirgule do
			tmpstring = m_PointVirgule[ifor1]
			MainStr = MainStr:Replace(tmpstring, tmpstring .. " ")
			MainStr = MainStr:Replace(" " .. tmpstring, tmpstring)
		end	
		aegisub.log(5,MainStr .. "\n\n")
		
		-- Rectification d'effet de bord :
		aegisub.log(5,"Rectification d'effet de bord :\n")
		for ifor1 = 1, #m_DblePonct do
			tmpstring = m_DblePonct[ifor1]
			MainStr = MainStr:Replace(tmpstring .. ".", tmpstring .. " .")
		end	
		aegisub.log(5,MainStr .. "\n\n")
		
		-- Opérations de fignolage en fin de traitement :
		-- On remplace les points de suspension :
		aegisub.log(5,"On remplace les points de suspension :\n")
		MainStr = MainStr:Replace(SuspReplacement, "... ")
		aegisub.log(5,MainStr .. "\n\n")
		
		-- Si on a des retours à la ligne par \N, on vérifie qu'il n'y a pas d'espace autour :
		aegisub.log(5,"Si on a des retours à la ligne par \\N, on vérifie qu'il n'y a pas d'espace autour :\n")
		MainStr = MainStr:Replace(" \\N", "\\N")
		MainStr = MainStr:Replace("\N ", "\\N")
		MainStr = MainStr:Replace(" \\n", "\\n")
		MainStr = MainStr:Replace("\\n ", "\\n")
		aegisub.log(5,MainStr .. "\n\n")
		
		-- Si le premier caractère de la chaine est un espace, on le vire :
		aegisub.log(5,"Si le premier caractère de la chaine est un espace, on le vire :\n")
		MainStr = MainStr:gsub("^ +","")
		MainStr = MainStr:gsub("^" .. TagReplacement .. " +", TagReplacement)
		aegisub.log(5,MainStr .. "\n\n")
		
		-- Si le dernier caractère de la chaine est un espace, on le vire :
		aegisub.log(5,"Si le dernier caractère de la chaine est un espace, on le vire :\n")
		MainStr = MainStr:gsub(" +$","")
		MainStr = MainStr:gsub(" +" .. TagReplacement .. "$", TagReplacement)
		aegisub.log(5,MainStr .. "\n\n")		
		
		-- Ajustement des parenthèses avec les doubles ponctuations :
		aegisub.log(5,"Ajustement des parenthèses avec les doubles ponctuations :\n")
		for ifor1 = 1, #m_DblePonct do
			tmpstring = m_DblePonct[ifor1]
			MainStr = MainStr:Replace(tmpstring .. " )", tmpstring .. ")")
		end	

		for ifor1 = 1, #m_DblePtsnCo do
			tmpstring = m_DblePtsnCo[ifor1]
			MainStr = MainStr:Replace(tmpstring .. " )", tmpstring .. ")")
		end	
		aegisub.log(5,MainStr .. "\n\n")

		-- Retrait des doubles espaces :
		aegisub.log(5,"Retrait des doubles espaces :\n")
		while MainStr:Contains("  ") do
			MainStr = MainStr:Replace("  ", " ")
		end
		while MainStr:Contains(" " .. TagReplacement .. " ") do
			MainStr = MainStr:Replace(" " .. TagReplacement .. " ", " " .. TagReplacement)
		end
		aegisub.log(5,MainStr .. "\n\n")
		
		-- rectification d'effet de bord sur le % :
		aegisub.log(5,"rectification d'effet de bord sur le %\n")
		for ifor1 = 1, #m_PointVirgule do
			tmpstring = m_PointVirgule[ifor1]
			MainStr = MainStr:Replace("% " .. tmpstring, "%" .. tmpstring)
		end		
		
		if ProblemeGuillemets then
			aegisub.log(5,"Notification de problème de guillemets\n")
			MainStr = "\{ErrGuillemets\}" .. MainStr
		end			
		
		-- Prise en compte des préférences :
		if iUseSuspChar then
			MainStr = MainStr:Replace("...", "…")
		end
		
		if iUseEspaceInsec then
			for ifor1 = 1, #m_DblePonct do
				tmpstring = m_DblePonct[ifor1]
				MainStr = MainStr:Replace(" " .. tmpstring, " " .. tmpstring)
				MainStr = MainStr:Replace(" " .. TagReplacement .. tmpstring, " " .. tmpstring)
			end
			for ifor1 = 1, #m_DblePtsnCo do
				tmpstring = m_DblePtsnCo[ifor1]
				MainStr = MainStr:Replace(" " .. tmpstring, " " .. tmpstring)
				MainStr = MainStr:Replace(" " .. TagReplacement .. tmpstring, " " .. tmpstring)
			end
		end
		
		if iUseApost then
			MainStr = MainStr:Replace("'", "’")
		else
			MainStr = MainStr:Replace("’", "'")
		end		
		
		
		
		-- On replace les tags à leur place :
		aegisub.log(5,"On replace les tags à leur place :\n")
		splitstringtext = MainStr:split(TagReplacement)
		MainStr = splitstringtext[1]
		
		for ifor1 = 2, #splitstringtext do
			MainStr = MainStr .. splitstringtag[ifor1 - 1] .. splitstringtext[ifor1]
		end
		
		aegisub.log(5,MainStr .. "\n\n")
		aegisub.log(5,"\n\n")
		return MainStr
	end

	-- function: string:split	
	-- purpose: Fonction transformant une ligne en tableau, sur la base d'un séparateur. S'utilise comme toute autre fonction de la classe string.
	-- @delimiter : séparateur à utiliser (généralement un caractère seul).
	-- @return : tableau résultat.
	function string:split(delimiter)
	  local result = { }
	  local from  = 1
	  local delim_from, delim_to = string.find( self, delimiter, from  )
	  while delim_from do
		table.insert( result, string.sub( self, from , delim_from-1 ) )
		from  = delim_to + 1
		delim_from, delim_to = string.find( self, delimiter, from  )
	  end
	  table.insert( result, string.sub( self, from  ) )
	  return result
	end

	-- function: string:Replace		
	-- purpose: Fonction de remplacement de texte (plain text)
	-- @oldstring : chaine à remplacer
	-- @newstring : chaine de remplacement	
	-- @return : ligne après remplacement
	function string:Replace(oldstring, newstring)
		local line=nil
		local str1 = oldstring
		local str2 = newstring
		
		-- préparation des chaines de remplacement pour échaper tous les caractères non alphanumériques
		str1 = str1:gsub("(%W)", "%%%1")
		str2 = str2:gsub("(%W)", "%%%1")
	
		-- réalisation du remplacement
		line = self:gsub(str1, str2)
		return line
	end
		
	-- function: string:Contains		
	-- purpose: Fonction indiquant la présence d'une chaine dans une autre.
	-- @str : chaine à rechercher
	-- @return : true si la chaine est trouvée, false sinon
	function string:Contains(str)
		local tmpstr = str:gsub("(%W)", "%%%1")
		local startid, endid
		startid, endid = self:find(tmpstr)
	
		if startid == nil then
			return false
		else
			return true
		end
	end	
	
---------------------------------------------------------------------
---- Macro Registrations - need to stay at the end of the script ----
---------------------------------------------------------------------
aegisub.register_macro("Corriger Ponctuation", "Corrige la ponctuation du script courant.", load_macro_ponct)