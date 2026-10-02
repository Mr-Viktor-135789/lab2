function DeleteObjects(Objs, Ruler)
%
% Удаление всех объектов, используемых в цикле обработки одного набора
% параметров

    for k = 1:Ruler.NumWorkers
        delete(Objs{k}.Source);
        delete(Objs{k}.Encoder);
        delete(Objs{k}.Interleaver);
        delete(Objs{k}.Mapper);
        delete(Objs{k}.Sig);
        delete(Objs{k}.Channel);
        delete(Objs{k}.Stat);
    end
    
    delete(Ruler);
end