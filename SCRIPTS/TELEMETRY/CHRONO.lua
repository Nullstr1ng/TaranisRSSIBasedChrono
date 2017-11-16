-- common stuff
local _countDownIndicatorIndex = 4
local _lastLapSwitchValue = 0;
local _lastTick = getTime();
local _bestLap = 123456;
local _lastCount = 0; -- used in count down

-- laps
local _isNewLap = false;
local _laps = {}
local _currentLapNumber = 0;
local _endTick = 0;
local _startTick = 0;
local _endLapTick = 0;
local _startLapTick = 0;

-- opentx version
local ver, radio, maj, minor, rev = getVersion();
local version = maj..'.'..minor;

-- screen setup
local max_width = 212;
local max_height = 64;
-- layout stuff
local _col_width = max_width / 3;
local _col1_row_height = max_height / 3; -- used only in first column
local _col3_row_height = max_height / 2;

-- config defaults
local _lapCount = 4
local _lapSwitch = 'ls1' -- a custom lap switch
local _throttle_channel = 'ch3'
local _isThrottleStart = false -- starts the throttle using timer.
local _throttle_trigger = -80 -- The throttle should be at %20 before the lap timer starts.
local _rssi_min_trigger = 80 -- the minimum rssi to trigger a new lap 80default
local _rssi_callout = false
local _vfas_callout = false
local _ls_names = {'ls1','ls2','ls3','ls4','ls5','ls6','ls7','ls8','ls9','ls10',}
local _ls_index = 1 -- check _lapSwitch

-- config helpers
local CONFIG_LAPS = 0;
local CONFIG_CUSTOM_SWITCH = 1;
local CONFIG_MIN_RSSI = 2;
local CONFIG_CURRENT = 0; -- default CONFIG_LAPS
local _incre = 0;

-- data sources
local DS_THR = 'thr';
local DS_ELE = 'ele';
local DS_RSSI = 'RSSI';
local DS_VFAS = 'VFAS';

-- pages
local PAGE_SPLASH = 0
local PAGE_CONFIG = 1
local PAGE_GOGGLES_DOWN = 2
local PAGE_COUNT_DOWN = 3
local PAGE_RUN = 4
local PAGE_POST_RUN = 5
local _currentPage = PAGE_CONFIG;

-- commons
function round(x)
  return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end

function round(num, decimals)
  local mult = 10^(decimals or 0)
  return math.floor(num * mult + 0.5) / mult
end

function PlayLap(num,lap) 
	if(lap > 0) then
		playFile('CHRONO/lap'..lap..'.wav');
		--playNumber(lap,0,0);
	end

	if maj == 2 then
		if minor == 1 then
			playNumber(num, 24, PREC2)
		elseif minor == 2 then
			if(num > 60) then
				playNumber(num, 26, PREC2)
			end
		end
	end	
end

function SecondsToClock(seconds)
  local seconds = tonumber(seconds)

  if seconds <= 0 then
    return "00:00:00";
  else
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.2f", (seconds - hours*3600 - mins *60));
    return hours..":"..mins..":"..secs
  end
end

function SecondsToMSMs(seconds)
	local seconds = tonumber(seconds)

	if seconds <= 0 then
		return "00:00:00";
	else
		mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
		secs = string.format("%02.2f", (seconds - hours*3600 - mins *60));
		return mins..":"..secs
	end
end

function iif(cond, T, F)
    if cond then return T else return F end
end

local function DRAW_SPLASH_PAGE(keyEvent)
	lcd.clear();
	
	lcd.drawText(1,1,getValue('s1'));
end

local function DRAW_CONFIG_PAGE(keyEvent)
	lcd.clear();
	lcd.drawScreenTitle('Configuration',0,0);
	
	rssi = getValue(DS_RSSI);
	lcd.drawText(169,0,'RSSI: '..rssi..'');
	
	ele = 0;
	if(math.floor(getTime() - _lastTick) / 100 > 1) then
		ele = getValue('ele');	
		_lastTick = getTime();		
	end
	
	if(ele < -980) then
		_incre = -1;
	elseif (ele > 980) then
		_incre = 1;
	elseif ((ele > -980 and ele < 0) or (ele < 980 and ele > 0)) then
		_incre = 0;
	else
		_incre = 0;
	end
	
	if(CONFIG_CURRENT == CONFIG_LAPS) then
		_lapCount = _lapCount + _incre;
		if(_lapCount < 1) then _lapCount = 1 end
	elseif (CONFIG_CURRENT == CONFIG_CUSTOM_SWITCH) then
		_ls_index = _ls_index + _incre;
		if(_ls_index < 1) then _ls_index = 1 end
		if(_ls_index > 10) then _ls_index = 10 end
		_lapSwitch = _ls_names[_ls_index];
	elseif (CONFIG_CURRENT == CONFIG_MIN_RSSI) then
		_rssi_min_trigger = _rssi_min_trigger + _incre;
		if(_rssi_min_trigger < 10) then _rssi_min_trigger = 10 end
	end
	
	lcd.drawText(2,9,'MAKE SURE YOUR KWAD IS DIARMED!');
	lcd.drawText(2,9*2,'Pitch up or down to adjust the values.');
	
	lcd.drawText(2,9*3,'Number of laps: ');
	lcd.drawText(lcd.getLastPos()+2,9*3,_lapCount,
		iif(CONFIG_CURRENT == CONFIG_LAPS,INVERS+BLINK,0)
	);
	
	lcd.drawText(2,9*4,'Custom switch in LS: ');
	lcd.drawText(lcd.getLastPos()+2,9*4,_lapSwitch,
		iif(CONFIG_CURRENT == CONFIG_CUSTOM_SWITCH,INVERS+BLINK,0)
	);
	
	lcd.drawText(2,9*5,'Minimum RSSI: ');
	lcd.drawText(lcd.getLastPos()+2,9*5,_rssi_min_trigger,
	--lcd.drawText(lcd.getLastPos()+2,9*5,getValue('ele'),
		iif(CONFIG_CURRENT == CONFIG_MIN_RSSI,INVERS+BLINK,0)
	);
	
	if(keyEvent == EVT_ENTER_BREAK) then
		_currentPage = PAGE_GOGGLES_DOWN;
	elseif(keyEvent == EVT_MINUS_BREAK) then
		CONFIG_CURRENT = CONFIG_CURRENT + 1;
		if(CONFIG_CURRENT > 2) then CONFIG_CURRENT = 2 end
	elseif(keyEvent == EVT_PLUS_BREAK) then
		CONFIG_CURRENT = CONFIG_CURRENT - 1;
		if(CONFIG_CURRENT < 0) then CONFIG_CURRENT = 0 end
	end
end

local function DRAW_GOGGLES_DOWN_PAGE(keyEvent)
	lcd.clear();	
	
	lcd.drawPixmap(0,0,'/bmp/chrono/gogdwn.bmp');
	
	lcd.drawText(109,14,'GOGGLES DOWN',MIDSIZE);
	
	lcd.drawText(110,42,'Press ENT to start');
	lcd.drawText(110,50,'the count-down.');
	
	if(keyEvent == EVT_ENTER_BREAK) then
		_lastTick = getTime();
		_currentPage = PAGE_COUNT_DOWN;		
		lcd.clear();
	elseif(keyEvent == EVT_PLUS_BREAK) then
		-- repeat goggles down audio
		playFile('CHRONO/gogdwn.wav');
	end
end

local function DRAW_PAGE_COUNT_DOWN(keyEvent)
	--lcd.clear();	
	--lcd.drawScreenTitle('COUNT DOWN',1,1);
	
	local duration = (getTime() - _lastTick) / 100;
	local countdown = 5 - duration;
	local cols = max_width / 5;
	local bmp = 0;
	
	if(countdown < 5 and math.floor(_lastCount) ~= math.floor(countdown)) then
		_lastCount = math.floor(countdown);
		bmp = math.floor(duration);
		lcd.drawPixmap(cols * bmp + 7, (max_height - 60) / 2, '/bmp/chrono/'..5-bmp..'.bmp');
		playFile('CHRONO/'..5-bmp..'.wav');
		--playNumber(5-bmp,0);
	end
	
	--local thr = getValue(DS_THR);
	
	if(keyEvent == EVT_ENTER_BREAK) or duration >= 5 or (5-bmp) == 0 then
		_lastTick = getTime();
		_startLapTick = getTime();
		_currentPage = PAGE_RUN;
	end
end

-- START - RUN PAGE methods
function DrawLayout()
	--lcd.drawRectangle(0,0,max_width,max_height,SOLID);
	
	-- create columns
	lcd.drawLine(_col_width,0,_col_width,max_height,SOLID,FORCE)
	lcd.drawLine(_col_width*2,0,_col_width*2,max_height,SOLID,FORCE)
	
	-- col 1
	-- draw rows
	lcd.drawLine(0,_col1_row_height,_col_width,_col1_row_height,SOLID,FORCE)
	lcd.drawLine(0,_col1_row_height*2,_col_width,_col1_row_height*2,SOLID,FORCE)
	
	
	--lcd.drawText(1,_col1_row_height+4,'AVE',SMLSIZE);
	lcd.drawText(1,_col1_row_height+4,'BST',SMLSIZE);
	lcd.drawText(1,(_col1_row_height*2)+4,'LAP',SMLSIZE);
	lcd.drawFilledRectangle(0,_col1_row_height+1,17,_col1_row_height*2,DARK,FORCE);
	
	-- col 2
	-- col 3
	lcd.drawLine(_col_width*2,_col3_row_height,_col_width*3,_col3_row_height,SOLID,FORCE)
end

function PrintAverage()
	local ave = 0
	if(#_laps > 0) then
		for i = 1, #_laps do
			ave = ave + _laps[i];
		end
		ave = ave / #_laps;
		lcd.drawText(19,_col1_row_height+5,SecondsToMSMs(ave),MIDSIZE);
	else
		lcd.drawText(19,_col1_row_height+5,SecondsToMSMs(0),MIDSIZE);
	end
end

function PrintBestTime()
	local best = 0;
	if(#_laps > 0) then
		best = _laps[1]
		for i = 1, #_laps do
			if(_laps[i] < best) then
				best = _laps[i]
			end
		end
		lcd.drawText(19,_col1_row_height+5,SecondsToMSMs(best),MIDSIZE);
	else
		lcd.drawText(19,_col1_row_height+5,SecondsToMSMs(0),MIDSIZE);
	end
end

function PrintLaps()
	lcd.drawText(19,(_col1_row_height*2)+5,_currentLapNumber..' - '.._lapCount,MIDSIZE);

	if #_laps == 0 then
		return;
	end
	
	if(#_laps > 0) then
		for i = 1, #_laps do
			lcd.drawText(
				_col_width+13,((i-1)*9) + 2, 
				i .. ': ' .. SecondsToMSMs(_laps[i])
			);
		end
	end
end

function DrawGauges()
	local rssi = getValue(DS_RSSI);
	local vfas = getValue(DS_VFAS);	
	
	lcd.drawText((_col_width*2)+3,3,'RSSI '..rssi);
	lcd.drawText((_col_width*2)+3,_col3_row_height + 3,'Batt '..round(vfas,2));
	
	lcd.drawGauge((_col_width*2)+3,14,_col_width-4,15,rssi,100);
	lcd.drawGauge((_col_width*2)+3,_col3_row_height+14,_col_width-4,15,vfas,16.8);
end
 
local function DRAW_RUN_PAGE(keyEvent)	 
	if(_currentLapNumber==_lapCount) then
		--_currentPage = PAGE_POST_RUN
		
		return;
	end	
	
	lcd.clear();

	DrawLayout();
	DrawGauges();
	
	-- print total elapsed time
	local elapsed = getTime() - _lastTick;
	local total_s = elapsed / 100;
	local elapsed_time = SecondsToClock(total_s);
	lcd.drawText(3,1,elapsed_time,MIDSIZE);	
	
	-- lap timer
	local lapTimeDuration = (getTime() - _startLapTick) / 100;
	lcd.drawText(3,13,'LD '..SecondsToMSMs(lapTimeDuration),SMLSIZE);
	
	--
	--local ele = getValue(DS_ELE);
	--local vfas = getValue(DS_VFAS);
	
	-- switches
	local custom_switch = getValue(_lapSwitch);
	local rssi = getValue(DS_RSSI);
	
	-- activate only if there's a changes in custom switch, rssi is greater than the rssi trigger and lap time is greater than 5
	if (_lastLapSwitchValue ~= custom_switch or rssi > _rssi_min_trigger) and lapTimeDuration > 5 then
		_lastLapSwitchValue = custom_switch;
		
		if (_lastLapSwitchValue > 0 or rssi > _rssi_min_trigger) then
			--_endTick = getTime();
			
			_currentLapNumber = _currentLapNumber + 1;
			--_lapDuration = (_endTick - _startTick) / 100;
			_laps[_currentLapNumber] = lapTimeDuration;
			
			PlayLap(_laps[#_laps] * 100, _currentLapNumber)
			
			if(lapTimeDuration < _bestLap) then
				_bestLap = lapTimeDuration;
				playFile('CHRONO/best.wav');
			end
			
			--_startTick = getTime();
			_startLapTick = getTime();
		end
	end
	
	--lcd.drawText(1,1,'Throttle: '..thr,0);
	--lcd.drawText(1,8,'Pitch: '..ele,0);
	--lcd.drawText(1,15,'RSSI: '..rssi,0);
	--lcd.drawText(1,22,'VFAS: '..vfas,0);
	--lcd.drawText(1,28,'ls6: '..custom_switch,0);
	
	PrintLaps();
	PrintBestTime();
end
-- END - RUN PAGE methods

local function DRAW_POST_RUN(keyEvent)
	lcd.clear();
	lcd.drawText(1,1,'POST RUN');
end

local function Init()
	
	_startTick = getTime();
end

local function Run(keyEvent)
	if _currentPage == PAGE_SPLASH then
		DRAW_SPLASH_PAGE(keyEvent)
	elseif _currentPage == PAGE_CONFIG then
		DRAW_CONFIG_PAGE(keyEvent)
	elseif _currentPage == PAGE_GOGGLES_DOWN then
		DRAW_GOGGLES_DOWN_PAGE(keyEvent)
	elseif _currentPage == PAGE_COUNT_DOWN then
		DRAW_PAGE_COUNT_DOWN(keyEvent)
	elseif _currentPage == PAGE_RUN then
		DRAW_RUN_PAGE(keyEvent)
	elseif _currentPage == PAGE_POST_RUN then
		DRAW_POST_RUN(keyEvent)
	end
end

return {init=Init, run=Run}