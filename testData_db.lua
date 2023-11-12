local MyAddOnName,NS = ...
local addon = _G[MyAddOnName]

addon.testData = {
		{ ["name"]="Superman",["unitID"]=1001,["classIndex"]=1,["classID"]="WARRIOR",["spec"]=3,},
        { ["name"]="WonderWoman",["unitID"]=1021,["classIndex"]=6,["classID"]="DEATHKNIGHT",["spec"]=3,},
        { ["name"]="IronMan",["unitID"]=1002,["classIndex"]=12,["classID"]="DEMONHUNTER",["spec"]=1,},
        { ["name"]="CaptainMarvel",["unitID"]=1003,["classIndex"]=7,["classID"]="SHAMAN",["spec"]=2,},
        { ["name"]="SpiderMan",["unitID"]=1004,["classIndex"]=9,["classID"]="WARLOCK",["spec"]=2,},
        { ["name"]="Batman",["unitID"]=1005,["classIndex"]=1,["classID"]="WARRIOR",["spec"]=2,},
        { ["name"]="Storm",["unitID"]=1006,["classIndex"]=7,["classID"]="SHAMAN",["spec"]=1,},
        { ["name"]="Theflash",["unitID"]=1007,["classIndex"]=4,["classID"]="ROGUE",["spec"]=3,},
        { ["name"]="Wolverine",["unitID"]=1027,["classIndex"]=4,["classID"]="ROGUE",["spec"]=1,},
        { ["name"]="ProfessorX",["unitID"]=1009,["classIndex"]=5,["classID"]="PRIEST",["spec"]=2,},
        { ["name"]="Grut",["unitID"]=1010,["classIndex"]=11,["classID"]="DRUID",["spec"]=4,},
        { ["name"]="Catwoman",["unitID"]=1032,["classIndex"]=10,["classID"]="MONK",["spec"]=2,},
        { ["name"]="Humantorch",["unitID"]=1012,["classIndex"]=8,["classID"]="MAGE",["spec"]=2,},
        { ["name"]="Hulk",["unitID"]=1013,["classIndex"]=10,["classID"]="MONK",["spec"]=1,},
}

addon.specDetails = {
    ["DEATHKNIGHT"] = { {["id"]=250,["name"]="Blood"},          {["id"]=251,["name"]="Frost"},          {["id"]=252,["name"]="UnHoly"},         {["id"]=0,["name"]="NONE"},},
    ["DEMONHUNTER"] = { {["id"]=577,["name"]="Havoc"},          {["id"]=581,["name"]=" Vengeance"},     {["id"]=0,["name"]="NONE"},             {["id"]=0,["name"]="NONE"},},
    ["DRUID"] = {       {["id"]=102,["name"]="Balance"},        {["id"]=103,["name"]="Fera"},           {["id"]=104,["name"]="Guardian"},       {["id"]=105,["name"]="Restoration"},},
    ["EVOKER"] = {      {["id"]=1467,["name"]="Devastation"},   {["id"]=1468,["name"]="Preservation"},  {["id"]=1473,["name"]="Augmentation"},  {["id"]=0,["name"]="NONE"},},
    ["HUNTER"] = {      {["id"]=253,["name"]="Beast Mastery"},  {["id"]=254,["name"]="Marksmanship"},   {["id"]=255,["name"]="Survival"},       {["id"]=0,["name"]="NONE"},},
    ["MAGE"] = {        {["id"]=62,["name"]="Arcane"},          {["id"]=63,["name"]="Fire"},            {["id"]=64,["name"]="Frost"},           {["id"]=0,["name"]="NONE"},},
    ["MONK"] = {        {["id"]=268,["name"]="Brewmaster"},     {["id"]=270,["name"]="Mistweaver"},     {["id"]=269,["name"]="Windwalker"},     {["id"]=0,["name"]="NONE"},},
    ["PALADIN"] = {     {["id"]=65,["name"]="Holy"},            {["id"]=66,["name"]="Protection"},      {["id"]=70,["name"]="Retribution"},     {["id"]=0,["name"]="NONE"},},
    ["PRIEST"] = {      {["id"]=256,["name"]="Discipline"},     {["id"]=257,["name"]="Holy"},           {["id"]=258,["name"]="Shadow"},         {["id"]=0,["name"]="NONE"},},
    ["ROGUE"] = {       {["id"]=259,["name"]="Assassination"},  {["id"]=260,["name"]="Outlaw"},         {["id"]=261,["name"]="Subtlety"},       {["id"]=0,["name"]="NONE"},},
    ["SHAMAN"] = {      {["id"]=262,["name"]="Elemental"},      {["id"]=263,["name"]="Enhancement"},    {["id"]=264,["name"]="Restoration"},    {["id"]=0,["name"]="NONE"},},
    ["WARLOCK"] = {     {["id"]=265,["name"]="Afflictio"},      {["id"]=266,["name"]="Demonology"},     {["id"]=267,["name"]="Destruction"},    {["id"]=0,["name"]="NONE"},},
    ["WARRIOR"] = {     {["id"]=71,["name"]="Arms"},            {["id"]=72,["name"]="Fury"},            {["id"]=73,["name"]="Protection"},      {["id"]=0,["name"]="NONE"},},
}