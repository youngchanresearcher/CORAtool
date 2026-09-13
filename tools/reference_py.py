"""Generate reference output from the Python CORA package for cross-checking."""
import json, sys, math
import pandas as pd
import cora


def norm(x):
    if x is None:
        return "NA"
    if isinstance(x, float) and math.isnan(x):
        return "NA"
    return "%.6f" % float(x)


def load(spec):
    if "csv" in spec:
        return pd.read_csv(spec["csv"], sep=spec.get("sep", ","))
    return pd.DataFrame(spec["data"], columns=spec["columns"])


def run(spec):
    df = load(spec)
    kwargs = dict(spec.get("kwargs", {}))
    if "mining" in spec:
        res = cora.data_mining(df, spec["outputs"], spec["mining"], **kwargs)
        return {"mining": ["{}::{}::{}::{}::{}".format(
            ", ".join(r.Combination), r.Nr_of_systems, norm(r.Inc_score),
            norm(r.Cov_score), norm(r.Score)) for r in res.itertuples()]}
    ctx = cora.OptimizationContext(df, spec["outputs"], **kwargs)
    out = {}
    tt = ctx.get_preprocessed_data()
    out["truth_table"] = tt.values.tolist()
    out["truth_table_cols"] = list(tt.columns)
    pis = ctx.get_prime_implicants()
    multi = len(ctx.output_labels) > 1
    if multi:
        out["prime_implicants"] = sorted(
            "{}|{}".format(p.implicant, ",".join(str(o) for o in sorted(p.outputs)))
            for p in pis
        )
    else:
        out["prime_implicants"] = sorted(str(p.implicant) for p in pis)
    out["pi_coverage"] = sorted(
        "{}::{}".format(p.implicant, ",".join(str(c) for c in sorted(p.coverage)))
        for p in pis
    )
    out["pi_scores"] = sorted(
        "{}::{}::{}".format(p.implicant, norm(p.coverage_score()),
                            norm(p.inclusion_score()))
        for p in pis
    )
    if multi:
        systems = ctx.get_irredundant_systems()
        out["solutions"] = sorted(
            "/".join(
                "+".join(sorted(str(i.implicant) for i in per_out))
                for per_out in s.system_multiple
            )
            for s in systems
        )
    else:
        systems = ctx.get_irredundant_sums()
        out["solutions"] = sorted(
            "+".join(sorted(str(i.implicant) for i in s.system)) for s in systems
        )
    out["solution_scores"] = sorted(
        "{}::{}".format(norm(s.coverage_score()), norm(s.inclusion_score()))
        for s in systems
    )
    return out


if __name__ == "__main__":
    specs = json.load(open(sys.argv[1]))
    print(json.dumps({k: run(v) for k, v in specs.items()}, indent=1, sort_keys=True))
