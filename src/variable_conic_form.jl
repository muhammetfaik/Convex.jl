function conic_form!(x::AbstractVariable, unique_conic_forms::UniqueConicForms)
    if !has_conic_form(unique_conic_forms, x)
        add_to_id_to_variables!(unique_conic_forms, x)
        if vexity(x) == ConstVexity()
            # do exactly what we would for a constant
            objective = ConicObj()
            objective[objectid(:constant)] = (vec([real(evaluate(x));]),vec([imag(evaluate(x));]))
            cache_conic_form!(unique_conic_forms, x, objective)
        else
            objective = ConicObj()
            vec_size = length(x)

            objective[x.id_hash] = (real_conic_form(x), imag_conic_form(x))
            objective[objectid(:constant)] = (spzeros(vec_size, 1), spzeros(vec_size, 1))
            # placeholder values in unique constraints prevent infinite recursion depth
            cache_conic_form!(unique_conic_forms, x, objective)
            if !(sign(x) == NoSign() || sign(x) == ComplexSign())
                conic_form!(sign(x), x, unique_conic_forms)
            end

            # apply the constraints `x` itself carries
            for constraint in constraints(x)
                conic_form!(constraint, unique_conic_forms)
            end
        end
    end
    return get_conic_form(unique_conic_forms, x)
end


USE_SPARSE() = true

# It might be useful to get a direct VOV sometimes...
function _template(a::AbstractVariable, context::Context{T}) where {T}
    var_inds = get!(context.var_id_to_moi_indices, a.id_hash) do
        return add_variables!(context.model, a::Variable)
    end
    context.id_to_variables[a.id_hash] = a

    for constraint in constraints(a)
        add_constraints_to_context(constraint, context)
    end

    return MOI.VectorOfVariables(var_inds)
end

function to_tape(v::MOI.VectorOfVariables, context::Context{T}) where T
    var_inds = v.variables
    d = length(var_inds)

    if USE_SPARSE()
        return SparseVAFTape([SparseAffineOperation(sparse(one(T)*I, d, d), Zero(d))], var_inds)

    else
        return VAFTape(tuple(AffineOperation(one(T)*I, Zero(d))), var_inds)
    end
end

# get the usual tape
template(a::AbstractVariable, context::Context) = to_tape(_template(a, context), context)
