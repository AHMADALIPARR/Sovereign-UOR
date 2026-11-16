//> using scala 3.5.2
package uor.dexoracle

import uor.kernel.Poly64

/** First side of the Poly64 dual oracle: the Scala kernel (src/main/scala/uor/kernel).
  * Prints one line per result in the format described in docs/dex-oracle.md.
  * dex/poly64.dx prints the same lines from an independent
  * dense implementation; CI requires the two outputs to be identical.
  */
object Poly64Vectors:
  private var state: Long = 0x5eedL
  private def next(): Long =
    state += 0x9e3779b97f4a7c15L
    var z = state
    z = (z ^ (z >>> 30)) * 0xbf58476d1ce4e5b9L
    z = (z ^ (z >>> 27)) * 0x94d049bb133111ebL
    z ^ (z >>> 31)
  private def small(k: Int): Int = java.lang.Long.remainderUnsigned(next(), k.toLong).toInt

  private def randomPoly(): Poly64 =
    val n = 1 + small(4)
    val exps = Array.fill(n)(Array(0, 0))
    val coeffs = new Array[Long](n)
    var i = 0
    while i < n do
      exps(i)(0) = small(4)
      exps(i)(1) = small(4)
      coeffs(i) = next()
      i += 1
    Poly64.fromRaw(2, exps, coeffs)

  private def hex(x: Long): String = f"$x%016x"

  private def terms(p: Poly64): String =
    if p.termCount == 0 then "0"
    else (0 until p.termCount).map(i => s"${p.exps(i)(0)},${p.exps(i)(1)}:${hex(p.coeffs(i))}").mkString(" ")

  def main(args: Array[String]): Unit =
    val cases = if args.nonEmpty then args(0).toInt else 200
    var c = 0
    while c < cases do
      val p = randomPoly()
      val q = randomPoly()
      val x = Array(next(), next())
      println(s"case $c add ${terms(p + q)}")
      println(s"case $c mul ${terms(p * q)}")
      println(s"case $c eval ${hex((p * q).eval(x).value)}")
      c += 1
