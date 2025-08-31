    -- Grab focus info
    local targetName = Entity.FocusTarget.Name
    local targetHomeworld = Entity.FocusTarget.HomeWorld

    yield("/echo I am " .. targetName .. " and I am from Homeworld " .. targetHomeworld)

    -- Excel lookup
    local sheetName = "World"
    local rowKey = targetHomeworld   -- use HomeWorld as the row identifier
    local columnKey = "Name"           -- example property/column you want

    -- Attempt to fetch from sheet
    local sheet = Excel.GetSheet(sheetName)
    local row = sheet:GetRow(rowKey)
    local whatIsProperty = nil

    if row then
        whatIsProperty = row:GetProperty(columnKey)
    else
        whatIsProperty = "<no row found>"
    end

    yield("/echo Hey what is this? .. " .. tostring(whatIsProperty))
