Config = {}

-- The item name in ox_inventory/data/items.lua
Config.ItemName = 'taser_laser' 

-- Maximum distance the laser travels
Config.MaxDistance = 80.0 

-- Define available colors (R, G, B, Alpha)
Config.Colors = {
    ['red']    = {label = 'Red',    color = {255, 0, 0, 200}},
    ['green']  = {label = 'Green',  color = {0, 255, 0, 200}},
    ['blue']   = {label = 'Blue',   color = {0, 0, 255, 200}},
    ['yellow'] = {label = 'Yellow', color = {255, 255, 0, 200}},
    ['pink']   = {label = 'Pink',   color = {255, 105, 180, 200}},
    ['purple'] = {label = 'Purple', color = {128, 0, 128, 200}},
    ['off']    = {label = 'Remove Laser', color = nil} -- Option to remove
}