local function makeDie(stage)
    local Die = { diagnostics = {} }

    function Die.error(message)
        table.insert(Die.diagnostics, { stage = stage, message = message, is_error = true })
    end

    function Die.fatal(message)
        -- error({ stage = stage, message = message }, 2)
        print(message)
        os.exit(false)
    end

    function Die.todo(message)
        -- error({ stage = stage, message = message }, 2)
        print('todo:', message)
        os.exit(false)
    end

    function Die.catch(f)
        local status, error=pcall(f)
        if not status then
            
        end
    end

    return Die
end

return makeDie
