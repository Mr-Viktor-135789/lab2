function Params = CalcAndCheckParams(inParams, LogLanguage)
%
% В этой функции можно проверять правильность установки комбинаций
% параметров и/или выполнять расчёт параметров одного класса, зависящих от
% параметров других классов, важно при этом понимать, что функция
% CalcAndCheckParams вызывается до создания объектов, т.е. до вызова
% конструкторов.

% Пересохраним входные данные
    Params = inParams;
    
% Если в модели отключено декодирование, то в демодуляторе нужно
% принудительно установить режим вынесения жёстких решений, иначе не
% удастся выполнить сравнение полученной и переданной информации
    if Params.Encoder.isTransparent
        Params.Mapper.DecisionMethod = 'Hard decision';
    end
    
% Проверка того, что в модулятор поступает число бит, делящееся на log2(M)
    if Params.Encoder.isTransparent
        % Как вариант, можно предусмотреть возможность набивания в
        % передатчике и отбрасывания в приёмнике дополнительных бит в
        % классе Mapper
        if mod(Params.Source.NumBitsPerFrame, ...
                log2(Params.Mapper.ModulationOrder)) > 0
            if strcmp(LogLanguage, 'Russian')
                error(['В модулятор поступает число бит не кратное ', ...
                    'log2(M).']);
            else
                error(['The number of bits at the input of the ', ...
                    'mapper is not multiple of log2(M).']);
            end
        end
    end
    