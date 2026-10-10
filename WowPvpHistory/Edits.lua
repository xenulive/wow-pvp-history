

















local _, A = ...


A.MANUAL_NOTE_MAX = 200


local RESULTS = { win = true, loss = true, draw = true }







local REASONS = { "disconnect", "crash", "client-closed", "chose-to-leave", "kicked" }

local REASON_SET = {}
for i = 1, #REASONS do
	REASON_SET[REASONS[i]] = true
end


function A.manualReasons()
	local out = {}
	for i = 1, #REASONS do
		out[i] = REASONS[i]
	end
	return out
end







local function block(subject)
	local manual = subject.manual
	if type(manual) ~= "table" then
		manual = { edits = 0 }
		subject.manual = manual
	end
	return manual
end





local function count(manual)
	manual.edits = (manual.edits or 0) + 1

	local ok, stamp = pcall(A.stamp)
	local read, epoch = pcall(time)

	if ok then
		manual.firstAt = manual.firstAt or stamp
		manual.lastAt = stamp
	end
	if read and type(epoch) == "number" then
		manual.firstEpoch = manual.firstEpoch or epoch
		manual.lastEpoch = epoch
	end
end








local function traceEdit(source, subject, state, reason)
	A.trace("edit", {
		source = source,
		id = type(subject) == "table" and subject.id or nil,
		state = state,
		reason = reason,
		n = type(subject) == "table" and type(subject.manual) == "table"
			and subject.manual.edits or nil,
	}, "data")
end




local function writeNote(subject, text, source)
	if type(subject) ~= "table" then
		traceEdit(source, subject, "refused", "no-subject")
		return false, nil, "no-subject"
	end

	if text ~= nil and #text > A.MANUAL_NOTE_MAX then
		traceEdit(source, subject, "refused", "too-long")
		return false, nil, "too-long", #text, A.MANUAL_NOTE_MAX
	end

	local manual = block(subject)
	local was = manual.note
	local cleared = text == nil or text == ""
	if cleared then
		manual.note = nil
	else
		manual.note = text
	end
	count(manual)
	traceEdit(source, subject, cleared and "cleared" or "filled")
	return true, was
end











function A.editResult(record, value)
	if type(record) ~= "table" then
		traceEdit("result", record, "refused", "no-record")
		return false, nil, "no-record"
	end
	if record.result ~= nil then
		traceEdit("result", record, "refused", "captured")
		return false, nil, "captured", record.result
	end


	if value ~= nil and type(A.carriesResult) == "function" and not A.carriesResult(record) then
		traceEdit("result", record, "refused", "no-result")
		return false, nil, "no-result"
	end




	if value ~= nil and type(A.resultCaptured) == "function" and A.resultCaptured(record) then
		traceEdit("result", record, "refused", "captured")
		local held = type(A.capturedResultText) == "function" and A.capturedResultText(record) or nil
		return false, nil, "captured", held
	end
	if value ~= nil and not RESULTS[value] then
		traceEdit("result", record, "refused", "bad-result")
		return false, nil, "bad-result"
	end

	local manual = block(record)
	local was = manual.result
	manual.result = value
	count(manual)
	traceEdit("result", record, value == nil and "cleared" or "filled")








	pcall(A.rebuildIndex)



	if type(A.overlayRepaint) == "function" then
		A.overlayRepaint("stored", "result")
	end



	if type(A.dropFinderWalk) == "function" then
		A.dropFinderWalk()
	end

	return true, was
end

function A.editNote(record, text)
	return writeNote(record, text, "note")
end







function A.roundTypedRefusal(record, index, value)
	local outcomes = type(A.roundOutcomes) == "function" and A.roundOutcomes(record) or nil
	local captured = type(outcomes) == "table" and outcomes[index] or nil
	if type(captured) == "table" and type(captured.won) == "boolean" then
		return "captured", captured.won and "win" or "loss"
	end
	if value ~= nil and type(A.roundTypedFits) == "function"
		and A.roundTypedFits(record, index, value == "win") == false then
		return "totals"
	end
	return nil
end


















function A.editRound(record, index, value)
	if type(record) ~= "table" then
		traceEdit("round", record, "refused", "no-record")
		return false, nil, "no-record"
	end
	local rounds = type(record.rounds) == "table" and record.rounds or nil
	if not rounds or type(index) ~= "number" or index ~= math.floor(index)
		or index < 1 or index > #rounds then
		traceEdit("round", record, "refused", "no-round")
		return false, nil, "no-round"
	end
	if value ~= nil and value ~= "win" and value ~= "loss" then
		traceEdit("round", record, "refused", "bad-result")
		return false, nil, "bad-result"
	end

	local refusal, blocking = A.roundTypedRefusal(record, index, value)
	if refusal then
		traceEdit("round", record, "refused", refusal)
		return false, nil, refusal, blocking
	end

	local manual = block(record)
	local typed = type(manual.rounds) == "table" and manual.rounds or {}
	local held = typed[index]
	local was = type(held) == "table" and held.result or nil
	if value == nil then
		typed[index] = nil
	else
		typed[index] = { result = value }
	end
	manual.rounds = next(typed) ~= nil and typed or nil
	count(manual)
	traceEdit("round", record, value == nil and "cleared" or "filled")

	if type(A.overlayRepaint) == "function" then
		A.overlayRepaint("stored", "round")
	end
	if type(A.dropFinderWalk) == "function" then
		A.dropFinderWalk()
	end
	return true, was
end
















function A.incompleteById(id)
	local db = A.db()
	if not (db and type(db.incomplete) == "table" and type(id) == "number") then
		return nil
	end
	local list = db.incomplete
	for i = #list, 1, -1 do
		if list[i].id == id then
			return list[i]
		end
	end
	return nil
end








function A.currentEditSubject(held, isLeft)
	if type(held) ~= "table" then
		return nil
	end
	if isLeft then
		return A.incompleteById(held.id)
	end
	return A.match(held.id)
end





function A.editReason(entry, token)
	if type(entry) ~= "table" then
		traceEdit("reason", entry, "refused", "no-entry")
		return false, nil, "no-entry"
	end
	if token ~= nil and not REASON_SET[token] then
		traceEdit("reason", entry, "refused", "bad-reason")
		return false, nil, "bad-reason"
	end

	local manual = block(entry)
	local was = manual.reason
	manual.reason = token
	count(manual)
	traceEdit("reason", entry, token == nil and "cleared" or "filled")
	return true, was
end

function A.editIncompleteNote(entry, text)
	return writeNote(entry, text, "incomplete-note")
end
