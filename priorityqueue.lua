priorityqueue = {}

priorityqueue.__index = priorityqueue

function priorityqueue:push(priority, value)
    table.insert(self.heap, {priority, value})

    local function siftUp(heap, index)
        while index > 1 do
            local parentIndex = math.floor(index / 2)
            if heap[parentIndex][1] <= heap[index][1] then
                break
            end
            heap[parentIndex], heap[index] = heap[index], heap[parentIndex]
            index = parentIndex
        end
    end

    siftUp(self.heap, #self.heap)
end

function priorityqueue:pop()
    if #self.heap == 0 then
        return nil
    end
    self.heap[1], self.heap[#self.heap] = self.heap[#self.heap], self.heap[1]
    local highestPriority = table.remove(self.heap)

    local function siftDown(heap, index)
        local size = #heap
        while 2 * index <= size do
            local left = 2 * index
            local right = left + 1
            local smallest = index

            if left <= size and heap[left][1] < heap[smallest][1] then
                smallest = left
            end
            if right <= size and heap[right][1] < heap[smallest][1] then
                smallest = right
            end
            if smallest == index then
                break
            end
            heap[smallest], heap[index] = heap[index], heap[smallest]
            index = smallest
        end
    end

    siftDown(self.heap, 1)
    return highestPriority[2]
end

function priorityqueue:peek()
    if #self.heap == 0 then
        return nil
    end
    return self.heap[1][2]
end

function priorityqueue:isempty()
    return #self.heap == 0
end

function priorityqueue:size()
    return #self.heap
end

function priorityqueue:cancel(value, compareFn)
    compareFn = compareFn or function(a, b) return a == b end
    local index = nil
    for i, v in ipairs(self.heap) do
        if compareFn(v[2], value) then
            index = i
            break
        end
    end
    if not index then
        return false
    end
    self.heap[index], self.heap[#self.heap] = self.heap[#self.heap], self.heap[index]
    table.remove(self.heap)

    local function siftDown(heap, index)
        local size = #heap
        while 2 * index <= size do
            local left = 2 * index
            local right = left + 1
            local smallest = index

            if left <= size and heap[left][1] < heap[smallest][1] then
                smallest = left
            end
            if right <= size and heap[right][1] < heap[smallest][1] then
                smallest = right
            end
            if smallest == index then
                break
            end
            heap[smallest], heap[index] = heap[index], heap[smallest]
            index = smallest
        end
    end

    local function siftUp(heap, index)
        while index > 1 do
            local parentIndex = math.floor(index / 2)
            if heap[parentIndex][1] <= heap[index][1] then
                break
            end
            heap[parentIndex], heap[index] = heap[index], heap[parentIndex]
            index = parentIndex
        end
    end

    siftDown(self.heap, index)
    siftUp(self.heap, index)
    return true
end

setmetatable(priorityqueue, {
    __call = function(self)
        return setmetatable({heap = {}}, self)
    end,
})

if arg and #arg == 1 and arg[1] == 'test' then
    local pq = priorityqueue()
    pq:push(5, "Task 5")
    pq:push(1, "Task 1")
    pq:push(3, "Task 3")
    pq:push(4, "Task 4")
    pq:push(2, "Task 2")
    assert("Task 1" == pq:peek())
    assert("Task 1" == pq:pop())
    assert("Task 2" == pq:peek())
    assert(4 == pq:size())
    assert(false == pq:isempty())
    assert(true == pq:cancel("Task 3"))
    assert(3 == pq:size())
    assert("Task 2" == pq:peek())
    print(debug.getinfo(1, 'S').source, 'tests passed')
end

return priorityqueue
