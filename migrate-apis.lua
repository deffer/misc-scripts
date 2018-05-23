#!/usr/bin/env lua

package.path = package.path .. ';/usr/local/share/lua/5.1/?.lua'
package.cpath = package.cpath .. ';/usr/local/lib/lua/5.1/?.so'

local http = require "socket.http"
local json = require('cjson')
local ltn12 = require("ltn12")

local srcKong = "http://localhost:8001/"
local targetKong = "http://10.10.25.208:9001/"


-- helper functions -----------
function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function listTableArray(data)
  for k, v in pairs(data) do
    print("|"..k.." -> "..tostring(type(v)).." -> "..tostring(v))

    if (type(v)=="table") then
      for dk, dv in pairs(v) do
        print("  |"..dk.." -> ("..tostring(type(dv))..") "..tostring(dv))
      end
    end

  end
end

function listTable(data)
  for k, v in pairs(data) do
    print("|"..k.." -> "..tostring(type(v)).." -> "..tostring(v))

    if (type(v)=="table") then
      for dk, dv in pairs(v) do
        print("  |"..dk.." -> ("..tostring(type(dv))..") "..tostring(dv))
      end
    end

  end
end


function toTableByIds(dataArray)
  local result = {}
  for k, v in pairs(dataArray) do
    result[v.id] = v
  end
  return result
end

function fetchApiPlugins(apiId)
  local result, statuscode, content = http.request(srcKong.."apis/"..apiId.."/plugins")
  local jdata = json.decode(result)
  local pluginsList = jdata.data
  --listTableArray(pluginsList)
  return toTableByIds(pluginsList)
end

local cpluginNames = {"key-auth", "oauth2", "acls", "basic-auth"}
function fetchConsumerPlugins(consumerId)
  local fresult = {}
  for _, v in ipairs(cpluginNames) do
    local result, statuscode, content = http.request(srcKong.."consumers/"..consumerId.."/"..v)
    local data = json.decode(result).data
    if tablelength(data)>0 then
      --print (srcKong.."consumers/"..consumerId.."/"..v)
      --print (result)
      --listTableArray(data)
      fresult[v] = data
    end
  end
  return fresult
end

function checkId(url)
  local response_body, statuscode, content = http.request(url)
  local result = json.decode(response_body)
  if tablelength(result)>0 and not result.id == nil then
    return result.id
  else
    return nil
  end
end

function sendPOST(postUrl, payload, debug)
  local response_body = { }

  local res, code, response_headers, status = http.request
    {
      url = postUrl,
      method = "POST",
      headers =
      {
        --["Authorization"] = "Maybe you need an Authorization header?",
        ["Content-Type"] = "application/json",
        ["Content-Length"] = payload:len()
      },
      source = ltn12.source.string(payload),
      sink = ltn12.sink.table(response_body)
    }

  local emptyResult = tablelength(response_body)==0
  if debug or emptyResult or not (code==201) then
    print('Response: = ' .. table.concat(response_body) .. ' code = ' .. code .. '   status = ' .. status)
    listTableArray(response_body)
  end
  if tablelength(response_body)>0 then
    return json.decode(response_body[1]).id
  else
    return nil
  end
end

function cleanRecord(record, cleanConsumer)
  record.id=nil
  record.created_at=nil
  if not (record.api_id==nil) then record.api_id=nil end
  if cleanConsumer and (not (record.consumer_id==nil)) then record.consumer_id=nil end
end

--  ---------------- APP START -------------
--print(package.path)
--print(type("Hello world").." is a type")

-- first read everything we can from source kong ---------
print("Querying source "..srcKong.."  for apis...")
result, statuscode, content = http.request(srcKong.."apis")
print("Status "..tostring(statuscode))
print("Content type is "..type(content))
print("Result is "..tostring(result))

-- 1. APIs  - id, name, upstream_url, request_path | request_host, ...
local jdata = json.decode(result)
local apisList = jdata.data
--listTableArray(apisList)
local apis = toTableByIds(apisList)
listTable(apis)

-- 2. consumers  - id, custom_id, username
result, statuscode, content = http.request(srcKong.."consumers")
jdata = json.decode(result)
local consumersList = jdata.data
listTableArray(consumersList)
local consumers = toTableByIds(consumersList)


-- 3. API plugins  - id, api_id, name, config (table) ...
local apiPlugins = {}
for k,v in pairs(apis) do
  apiPlugins[k] = fetchApiPlugins(k)
  print( "--- api "..v.name.." has "..tostring(tablelength(apiPlugins[k])).." plugins")
end

-- 4. consumer plugins  - id, consumer_id, ...
local consumerPlugins = {}
local consumerPluginsAvg = 0
for k,v in pairs(consumers) do
  local pluginsMap = fetchConsumerPlugins(k)
  consumerPlugins[k] = pluginsMap
  consumerPluginsAvg = consumerPluginsAvg + tablelength(pluginsMap)
end

print ("At least "..tostring(consumerPluginsAvg).." plugins for consumers")

-- import everything one by one into target kong
-- remember new ids to be able to remap plugins to new ids
local apiMap = {}
local consumerMap = {}

local apipath = targetKong.."apis"
local consumerPath = targetKong.."consumers"
--local ppayload = [[ { "upstream_url":"https://api.github.com/users","request_path": "/lemon", "strip_request_path": true, "name": "lemon"} ]]
--local newId = sendPOST(apipath, ppayload, false)
--print ("Returned id is "..tostring(newId))

-- 1) and 3) Import APIs and plugins configured for them
for k,v in pairs(apis) do
  local newId = checkId(apipath.."/"..v.name)
  if (newId==nil) then
    print ("\nCreating API "..v.name)
    cleanRecord(v, false)
    newId = sendPOST(apipath, json.encode(v), false)
    print("New API id is "..tostring(newId))
  else
    print ("\nExisting API "..v.name.." - id is "..tostring(newId))
  end
  apiMap[k] = newId

  if (not (newId == nil)) then
    for i,plugin in pairs(apiPlugins[k]) do
      print("  Creating plugin "..plugin.name)
      cleanRecord(plugin, false)
      -- http://kong:8001/apis/{api}/plugins   -  {name: '', config: ''}
      sendPOST(apipath.."/"..newId.."/plugins", json.encode(plugin), true)
    end
  end
end

-- 2) and 4) Import consumers and plugins configured for them
for k,v in pairs(consumers) do
  if (v.username == nil) then
    print("\nSkipping "..v.custom_id.." as it has empty username")
  else
    local newId = checkId(consumerPath.."/"..v.username)
    if (newId==nil) then
      print ("\nCreating consumer "..v.username)
      cleanRecord(v, true)
      newId = sendPOST(consumerPath, json.encode(v), true)
      print("New consumer id is "..tostring(newId))
    else
      print ("\nExisting consumer "..v.username.." - id is "..tostring(newId))
    end
    consumerMap[k] = newId

    if (not (newId == nil)) then
      for cptype,cp in pairs(consumerPlugins[k]) do
        print("  Creating "..tostring(tablelength(cp)).." plugin(s) of type "..cptype)
        for i,entry in ipairs(cp) do
          cleanRecord(entry, true)
          print("    "..cptype..":  "..json.encode(entry))
          --http://kong:8001/consumers/{consumer}/acls
          sendPOST(consumerPath.."/"..newId.."/"..cptype, json.encode(entry), true)
        end
      end
    end
  end
end