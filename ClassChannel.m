classdef ClassChannel < handle
    properties (SetAccess = private) % Переменные из параметров
        % Нужно ли пропускать сигнал через канал
            isTransparent;
        % Переменная управления языком вывода информации для пользователя
            LogLanguage;
    end
    properties (SetAccess = private) % Вычисляемые переменные
        % Значение средней мощности модуляционного символа
            Ps;
        % Значение средней мощности модуляционного бита
            Pb;
        % Значение средней мощности информационного бита
            Pbd;
    end
    methods
        function obj = ClassChannel(Params, Objs, LogLanguage)
        % Конструктор
            % Выделим поля Params, необходимые для инициализации
                Channel = Params.Channel;
            % Инициализация значений переменных из параметров
                obj.isTransparent = Channel.isTransparent;
            % Переменная LogLanguage
                obj.LogLanguage = LogLanguage;

            % Определим среднюю мощность модуляционного символа
                Const = Objs.Mapper.Constellation;
                obj.Ps = mean((abs(Const)).^2);

            % Определим среднюю мощность модуляционного бита
                obj.Pb = obj.Ps / Objs.Mapper.log2M;

            % Определим среднюю мощность информационного бита (энергия,
            % приходящаяся на информационный бит, оказывается больше, так
            % как используются проверочные биты)
                obj.Pbd = obj.Pb;
                % Когда и если будет реализован класс кодирования, то здесь
                % должно будет быть
                % obj.Pbd = obj.Pb / Objs.Encoder.Rate;
        end
        function [OutData, InstChannelParams] = Step(obj, InData, h2dB)
            if obj.isTransparent
                OutData = InData;
                InstChannelParams.Variance = 1;
                return
            end

            % Сформируем АБГШ
                Sigma = sqrt(obj.Pbd * 10^(-h2dB/10) / 2);
                InstChannelParams.Variance = 2*Sigma^2;
                Noise = randn(length(InData), 2) * [1; 1i] * Sigma;

            % Добавим его к сигналу
                OutData = InData + Noise;
        end
    end
end