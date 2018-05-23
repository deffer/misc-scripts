#!/usr/bin/env lua

package.path = package.path .. ';/usr/local/share/lua/5.1/?.lua'
package.cpath = package.cpath .. ';/usr/local/lib/lua/5.1/?.so'

local http = require "socket.http"
local json = require('cjson')
local ltn12 = require("ltn12")

local srcKong = "http://localhost:8001/"
-- local targetKong = "http://10.10.25.208:9001/"


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

--convert list into map
function toTableByIds(dataArray)
  local result = {}
  for k, v in pairs(dataArray) do
    result[v.id] = v
  end
  return result
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


-- 2. consumers  - id, custom_id, username
result, statuscode, content = http.request(srcKong.."consumers")
print("Status "..tostring(statuscode))
print("Content type is "..type(content))
print("Result is "..tostring(result))

local jdata = json.decode(result)
local consumersList = jdata.data
--listTableArray(consumersList)
local consumers = toTableByIds(consumersList)


-- 4. consumer plugins  - id, consumer_id, ...
local consumerPlugins = {}
local consumerPluginsAvg = 0
for k,v in pairs(consumers) do
  local pluginsMap = fetchConsumerPlugins(k)
    if type(pluginsMap["oauth2"]) == "table" then
      print (""..k.."   "..tostring(pluginsMap["oauth2"]))
    end
  consumerPlugins[k] = pluginsMap
  consumerPluginsAvg = consumerPluginsAvg + tablelength(pluginsMap)
end

print ("At least "..tostring(consumerPluginsAvg).." plugins for consumers")
