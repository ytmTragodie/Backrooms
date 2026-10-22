class_name CutOutPreview
extends RefCounted
## 预览为公开信息，不包含尚未知晓的目标身份，且不接触 RNG。
var allowed: bool = false
var labels: Array[String] = []
var probabilities: Array[float] = []
var modifiers: Array[String] = []
