local simUI={}

--@fun insertTableRow
--@arg int ui the ui handle
--@arg int widget the widget identifier
--@arg int index the index (0-based) where the new row will appear
function simUI.insertTableRow(ui,widget,index)
    local rows=simUI.getRowCount(ui,widget)
    local cols=simUI.getColumnCount(ui,widget)
    simUI.setRowCount(ui,widget,rows+1)
    for row=rows-1,index+1,-1 do
        for col=0,cols-1 do
            simUI.setItem(ui,widget,row,col,simUI.getItem(ui,widget,row-1,col))
        end
    end
end

--@fun removeTableRow
--@arg int ui the ui handle
--@arg int widget the widget identifier
--@arg int index the row index (0-based) to remove
function simUI.removeTableRow(ui,widget,index)
    local rows=simUI.getRowCount(ui,widget)
    local cols=simUI.getColumnCount(ui,widget)
    for row=index,rows-2 do
        for col=0,cols-1 do
            simUI.setItem(ui,widget,row,col,simUI.getItem(ui,widget,row+1,col))
        end
    end
    simUI.setRowCount(ui,widget,rows-1)
end

--@fun insertTableColumn
--@arg int ui the ui handle
--@arg int widget the widget identifier
--@arg int index the index (0-based) where the new column will appear
function simUI.insertTableColumn(ui,widget,index)
    local rows=simUI.getRowCount(ui,widget)
    local cols=simUI.getColumnCount(ui,widget)
    simUI.setColumnCount(ui,widget,cols+1)
    for col=cols-1,index+1,-1 do
        for row=0,rows-1 do
            simUI.setItem(ui,widget,row,col,simUI.getItem(ui,widget,row,col-1))
        end
    end
end

--@fun removeTableColumn
--@arg int ui the ui handle
--@arg int widget the widget identifier
--@arg int index the column index (0-based) to remove
function simUI.removeTableColumn(ui,widget,index)
    local rows=simUI.getRowCount(ui,widget)
    local cols=simUI.getColumnCount(ui,widget)
    for col=index,cols-2 do
        for row=0,rows-1 do
            simUI.setItem(ui,widget,row,col,simUI.getItem(ui,widget,row,col+1))
        end
    end
    simUI.setColumnCount(ui,widget,cols-1)
end

return simUI
