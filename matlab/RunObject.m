classdef (Abstract) RunObject < handle
    
    % Abstract class to show that a subclass is meant to be '.run()'
    
    properties (SetAccess=protected)
        % String describing all parameters for easy comparison,
        % generally defined by =str(obj) at the end of initialisation step
        name string
        has_run logical = false
    end
    
    methods (Abstract)
        run(obj, previous_obj) % Used to execute what this object is made for
    end
    
    methods
        function init_params(obj, params)
            change_parameters(obj, params);
            parameters2name(obj);
        end
        
        function change_parameters(obj, params)
            % Change the parameters given in the struct params
            if ~exist('params', 'var') || isempty(params)
                return
            end
            param_fields = fields(params);
            for k = 1:length(param_fields)
                f = param_fields{k};
                if ~isprop(obj, f)
                    % It breaks with assert because of params transmission 
                    % assert(isprop(obj, f), f)
                    continue
                end
                if isa(obj.(f), 'RunObject')
                    % Those are initialised with appropriate inputs
                    continue
                end
                obj.(f) = params.(f);
            end
        end
        
        function parameters2name(o)
            % Sets names using subclass.names and parameter values
            p = properties(o);
            p = sort(p);
            s = class(o); % '';
            for k = 1:length(p)
                prop = p{k};
                if ismember(prop, {'name', 'has_run'})
                    continue
                end
                v = o.(prop);
                s_ = v2s(v);
                if ~isempty(s_)
                    s = strcat(s, prop(1), s_);
                end
            end
            s = replace_problematic_symbols(s);
            o.name = s;
        end
    end
    
end

function s_ = v2s(v)
% Transforms a value into a string, depending on its class
s_ = '';
if isempty(v)
    return
end
switch class(v)
    case 'struct'
        % We avoid using structs: they normally just pass on data for later
    case 'function_handle', s_ = func2str(v);
    case 'double'
        if length(v) <= 1
            s_ = sprintf('%.2d', v);
        else
            % s_ = sprintf('%.2d%.2d%d', min(v), max(v), length(v));
            s_ = sprintf('%0.4g%0.4g%d', min(v), max(v), length(v));
        end
    case 'char', s_ = v;
    case 'cell'
        switch class(v{1})
            case 'double', s_ = sprintf('%d', v{:});
            case 'char', s_ = sprintf('%s', v{:});
        end
        
    otherwise
        if isa(v, 'RunObject')
            s_ = v.name;
        end
end
end

function s = replace_problematic_symbols(s)
s = strrep(s, '.', 'D');
s = strrep(s, '-', 'M');
s = strrep(s, '+', 'P');
end